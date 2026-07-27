//
//  HotkeyManager.swift
//  MiniMe
//

import AppKit
import Carbon

// Global callback function for Carbon event handler (must be at file scope)
private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    guard err == noErr else { return err }

    DispatchQueue.main.async {
        HotkeyManager.handleHotkey(id: hotkeyID.id, signature: hotkeyID.signature)
    }

    return noErr
}

@MainActor
class HotkeyManager: ObservableObject {
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var escapeHotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @Published var hasAccessibilityPermission: Bool = true // Not needed for Carbon hotkeys

    var onCapture: (@MainActor () -> Void)?
    var onTypeIt: (@MainActor () -> Void)?
    var onToggleMouseMove: (@MainActor () -> Void)?
    var onEscape: (@MainActor () -> Void)?
    var onClipboard: (@MainActor () -> Void)?

    private var shortcuts = ShortcutSet(
        capture: .defaultCapture,
        typeIt: .defaultTypeIt,
        moveMouse: .defaultMoveMouse,
        clipboard: .defaultClipboard
    )

    // Signature "KIMO" for main hotkeys
    private static let mainSignature = OSType(0x4B494D4F)
    private static let captureHotkeyID = EventHotKeyID(signature: mainSignature, id: 1)
    // id 2 was the history hotkey, retired with the capture-history feature.
    private static let escapeHotkeyID = EventHotKeyID(signature: mainSignature, id: 3)
    private static let typeItHotkeyID = EventHotKeyID(signature: mainSignature, id: 4)
    private static let moveMouseHotkeyID = EventHotKeyID(signature: mainSignature, id: 5)
    private static let clipboardHotkeyID = EventHotKeyID(signature: mainSignature, id: 6)

    private static weak var sharedInstance: HotkeyManager?

    init() {
        HotkeyManager.sharedInstance = self
        setupEventHandler()
    }

    deinit {
        // Note: Can't call stopMonitoring() directly in deinit for @MainActor class
        // The refs will be cleaned up when the process exits
    }

    func checkAccessibilityPermission() {
        // Carbon hotkeys don't require accessibility permission
        hasAccessibilityPermission = true
    }

    func requestAccessibilityPermission() {
        // Not needed for Carbon hotkeys, but keep for screen recording
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func updateShortcuts(_ shortcuts: ShortcutSet) {
        self.shortcuts = shortcuts
        startMonitoring()
    }

    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )

        print("[HotkeyManager] Installed event handler, status=\(status)")
    }

    static func handleHotkey(id: UInt32, signature: OSType) {
        Task { @MainActor in
            guard let manager = sharedInstance else {
                print("[HotkeyManager] No shared instance!")
                return
            }

            // Only handle our hotkeys (signature "KIMO")
            guard signature == mainSignature else { return }

            switch id {
            case 1:
                print("[HotkeyManager] Capture hotkey triggered")
                manager.onCapture?()
            case 4:
                print("[HotkeyManager] Type It hotkey triggered")
                manager.onTypeIt?()
            case 5:
                print("[HotkeyManager] Move Mouse hotkey triggered")
                manager.onToggleMouseMove?()
            case 3:
                print("[HotkeyManager] Escape hotkey triggered")
                manager.onEscape?()
            case 6:
                print("[HotkeyManager] Clipboard hotkey triggered")
                manager.onClipboard?()
            default:
                print("[HotkeyManager] Unknown hotkey id: \(id)")
            }
        }
    }

    func startMonitoring() {
        stopMonitoring()

        HotkeyManager.sharedInstance = self

        // A tool switched off in Settings gets no hotkey.
        if shortcuts.isEnabled(.capture) {
            register(shortcuts.capture, id: Self.captureHotkeyID, label: "capture")
        }
        if shortcuts.isEnabled(.typeIt) {
            register(shortcuts.typeIt, id: Self.typeItHotkeyID, label: "type it")
        }
        if shortcuts.isEnabled(.moveMouse) {
            register(shortcuts.moveMouse, id: Self.moveMouseHotkeyID, label: "move mouse")
        }
        if shortcuts.isEnabled(.clipboard) {
            register(shortcuts.clipboard, id: Self.clipboardHotkeyID, label: "clipboard")
        }
    }

    private func register(_ shortcut: CustomShortcut, id: EventHotKeyID, label: String) {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(from: shortcut.modifiers),
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref {
            hotkeyRefs[id.id] = ref
        }

        print("[HotkeyManager] Registered \(label) hotkey: keyCode=\(shortcut.keyCode), status=\(status)")
    }

    func stopMonitoring() {
        for ref in hotkeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
    }

    // MARK: - Escape Hotkey (for selection mode)

    func registerEscapeHotkey() {
        unregisterEscapeHotkey()

        let status = RegisterEventHotKey(
            UInt32(53), // Escape key
            0,          // No modifiers
            Self.escapeHotkeyID,
            GetApplicationEventTarget(),
            0,
            &escapeHotkeyRef
        )

        print("[HotkeyManager] Registered escape hotkey, status=\(status)")
    }

    func unregisterEscapeHotkey() {
        if let ref = escapeHotkeyRef {
            UnregisterEventHotKey(ref)
            escapeHotkeyRef = nil
            print("[HotkeyManager] Unregistered escape hotkey")
        }
    }

    private func carbonModifiers(from cocoaModifiers: UInt) -> UInt32 {
        var carbonMods: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: cocoaModifiers)

        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        return carbonMods
    }
}
