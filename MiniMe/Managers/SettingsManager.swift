//
//  SettingsManager.swift
//  MiniMe
//

import SwiftUI
import ServiceManagement
import IOKit.pwr_mgt

enum SleepDuration: String, CaseIterable, Identifiable {
    case tenMinutes   = "10 minutes"
    case thirtyMinutes = "30 minutes"
    case oneHour      = "1 hour"
    case twoHours     = "2 hours"
    case fourHours    = "4 hours"
    case eightHours   = "8 hours"
    case infinite     = "Infinite"

    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .tenMinutes:    return 600
        case .thirtyMinutes: return 1800
        case .oneHour:       return 3600
        case .twoHours:      return 7200
        case .fourHours:     return 14400
        case .eightHours:    return 28800
        case .infinite:      return nil
        }
    }
}

@MainActor
class SettingsManager: ObservableObject {
    @AppStorage("playSound") var playSound = true
    @AppStorage("recognitionLanguage") var recognitionLanguage = "automatic"
    @AppStorage("lineAwareOCR") var lineAwareOCR = true
    @AppStorage("ocrAccuracy") var ocrAccuracy = "accurate"
    @AppStorage("useLanguageCorrection") var useLanguageCorrection = false
    @AppStorage("typeItCountdownDuration") var typeItCountdownDuration = 5
    @AppStorage("typeItCountdownSound") var typeItCountdownSound = true

    // Clipboard manager (on/off lives in `Tool.clipboard`, not here)
    @AppStorage("clipboardPickBehavior") var clipboardPickBehavior = PasteService.PickBehavior.copyAndPaste.rawValue
    @AppStorage("clipboardCaptureImagesAndFiles") var clipboardCaptureImagesAndFiles = true
    @AppStorage("clipboardIgnoreConcealed") var clipboardIgnoreConcealed = true
    @AppStorage("clipboardMaxEntries") var clipboardMaxEntries = 200

    // Scheduled action (config persists; armed runtime state does not — see ScheduledActionManager)
    @AppStorage("scheduledText") var scheduledText = ""
    @AppStorage("scheduledComboEnabled") var scheduledComboEnabled = true
    @AppStorage("scheduledIntervalValue") var scheduledIntervalValue = 1
    @AppStorage("scheduledIntervalUnit") var scheduledIntervalUnit = ScheduleUnit.hours.rawValue
    @AppStorage("scheduledRepeat") var scheduledRepeat = false

    // Mouse mover (config persists; armed runtime state does not — see MouseMoverManager)
    @AppStorage("mouseMoverMinSeconds") var mouseMoverMinSeconds = 5
    @AppStorage("mouseMoverMaxSeconds") var mouseMoverMaxSeconds = 12

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    @Published var captureShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var typeItShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var moveMouseShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var clipboardShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var scheduledCombo: CustomShortcut {
        didSet { saveScheduledCombo() }
    }

    @Published private(set) var activeSleepDuration: SleepDuration? = nil
    private var sleepAssertionID: IOPMAssertionID = .zero
    private var sleepTimer: Timer?

    /// Which tools are switched on. See `Tool`.
    @Published private(set) var enabledTools: Set<Tool>

    var shortcutSet: ShortcutSet {
        ShortcutSet(
            capture: captureShortcut,
            typeIt: typeItShortcut,
            moveMouse: moveMouseShortcut,
            clipboard: clipboardShortcut,
            enabledTools: enabledTools
        )
    }

    func isEnabled(_ tool: Tool) -> Bool { enabledTools.contains(tool) }

    /// Switches a tool on or off and releases anything this object owns on its
    /// behalf. Teardown for objects owned by `MiniMeApp` — the clipboard
    /// monitor and panel, the capture overlay, the mouse mover — hangs off the
    /// `enabledTools` observer in `MiniMeApp`.
    func setEnabled(_ tool: Tool, _ enabled: Bool) {
        guard enabledTools.contains(tool) != enabled else { return }

        Tool.setEnabled(enabled, for: tool, in: defaults)
        if enabled {
            enabledTools.insert(tool)
        } else {
            enabledTools.remove(tool)
        }

        // Prevent Sleep holds an IOKit assertion. Dropping the UI that releases
        // it without releasing it would keep the Mac awake with no way to stop.
        if tool == .preventSleep && !enabled {
            disablePreventSleep()
        }
    }

    func enablePreventSleep(_ duration: SleepDuration) {
        // Release any existing assertion first
        disablePreventSleep()

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MiniMe: Prevent Sleep" as CFString,
            &sleepAssertionID
        )
        guard result == kIOReturnSuccess else { return }

        activeSleepDuration = duration

        if let seconds = duration.seconds {
            sleepTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in self?.disablePreventSleep() }
            }
        }
    }

    func disablePreventSleep() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        if sleepAssertionID != .zero {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = .zero
        }
        activeSleepDuration = nil
    }

    private var settingsWindow: NSWindow?

    /// Injectable so tests can run against a scratch domain instead of the
    /// user's real preferences. `@AppStorage` properties above always use
    /// `.standard`; this store backs the shortcuts and tool enablement.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        Tool.migrateLegacyKeys(in: defaults)
        enabledTools = Tool.enabledSet(from: defaults)

        if let data = defaults.data(forKey: "captureShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            captureShortcut = shortcut
        } else {
            captureShortcut = .defaultCapture
        }

        if let data = defaults.data(forKey: "typeItShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            typeItShortcut = shortcut
        } else {
            typeItShortcut = .defaultTypeIt
        }

        if let data = defaults.data(forKey: "moveMouseShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            moveMouseShortcut = shortcut
        } else {
            moveMouseShortcut = .defaultMoveMouse
        }

        if let data = defaults.data(forKey: "clipboardShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            clipboardShortcut = shortcut
        } else {
            clipboardShortcut = .defaultClipboard
        }

        if let data = defaults.data(forKey: "scheduledCombo"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            scheduledCombo = shortcut
        } else {
            scheduledCombo = CustomShortcut(keyCode: 36, modifiers: 0) // Return
        }
    }

    private func saveScheduledCombo() {
        if let data = try? JSONEncoder().encode(scheduledCombo) {
            defaults.set(data, forKey: "scheduledCombo")
        }
    }

    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(captureShortcut) {
            defaults.set(data, forKey: "captureShortcut")
        }
        if let data = try? JSONEncoder().encode(typeItShortcut) {
            defaults.set(data, forKey: "typeItShortcut")
        }
        if let data = try? JSONEncoder().encode(moveMouseShortcut) {
            defaults.set(data, forKey: "moveMouseShortcut")
        }
        if let data = try? JSONEncoder().encode(clipboardShortcut) {
            defaults.set(data, forKey: "clipboardShortcut")
        }
    }

    func resetToDefaults() {
        captureShortcut = .defaultCapture
        typeItShortcut = .defaultTypeIt
        moveMouseShortcut = .defaultMoveMouse
        clipboardShortcut = .defaultClipboard
    }

    func showSettingsWindow(
        hotkeyManager: HotkeyManager,
        updateManager: UpdateManager,
        clipboardStore: ClipboardStore
    ) {
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settings: self,
            hotkeyManager: hotkeyManager,
            updateManager: updateManager,
            clipboardStore: clipboardStore
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 680, height: 460))
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}
