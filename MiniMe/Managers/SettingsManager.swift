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

/// A Prevent Sleep session as it survives a relaunch. `remaining` is nil for
/// `.infinite`, which never runs out; a finite session that expired while the
/// app was closed does not produce a session at all.
struct PreventSleepSession: Equatable {
    let duration: SleepDuration
    let remaining: TimeInterval?
}

@MainActor
class SettingsManager: ObservableObject {
    @AppStorage("playSound") var playSound = true
    @AppStorage("automaticUpdateChecks") var automaticUpdateChecks = true
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

    // Paper matte. Unlike the mouse mover, whether it is on persists too — the
    // key is owned by `PaperOverlayManager`, which restores it at launch.
    @AppStorage(PaperOverlayManager.textureKey) var paperTexture = PaperTexture.matte.rawValue
    @AppStorage(PaperOverlayManager.strengthKey) var paperStrength = PaperStrength.defaultValue

    /// The chosen texture, falling back to the default if the stored value is
    /// from a build that spelled it differently.
    var paperTextureValue: PaperTexture {
        PaperTexture(rawValue: paperTexture) ?? .matte
    }

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
    @Published var paperShortcut: CustomShortcut {
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
            paper: paperShortcut,
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
        guard holdSleepAssertion(duration, remaining: duration.seconds) else { return }
        saveSleepSession(duration, remaining: duration.seconds)
    }

    func disablePreventSleep() {
        releaseSleepAssertion()
        clearSleepSession()
    }

    /// Takes the IOKit assertion and arms the expiry timer. `remaining` is the
    /// time left to run, which is shorter than the duration when a session is
    /// being resumed after a relaunch.
    @discardableResult
    private func holdSleepAssertion(_ duration: SleepDuration, remaining: TimeInterval?) -> Bool {
        // Release any existing assertion first
        releaseSleepAssertion()

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MiniMe: Prevent Sleep" as CFString,
            &sleepAssertionID
        )
        guard result == kIOReturnSuccess else { return false }

        activeSleepDuration = duration

        if let remaining {
            sleepTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in self?.disablePreventSleep() }
            }
        }
        return true
    }

    /// Drops the assertion without touching the stored session — what a quit
    /// does, since the kernel reclaims the assertion when the process exits.
    /// Not `private` so tests can stand in for that quit.
    func releaseSleepAssertion() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        if sleepAssertionID != .zero {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = .zero
        }
        activeSleepDuration = nil
    }

    // MARK: - Prevent Sleep persistence

    private static let sleepDurationKey = "preventSleepDuration"
    private static let sleepExpiryKey = "preventSleepExpiry"

    /// The session stored by a previous launch, or nil when Prevent Sleep was
    /// off — or when a finite session ran out while the app was not running.
    static func savedSleepSession(in defaults: UserDefaults, now: Date = Date()) -> PreventSleepSession? {
        guard let raw = defaults.string(forKey: sleepDurationKey),
              let duration = SleepDuration(rawValue: raw) else { return nil }

        guard duration.seconds != nil else {
            return PreventSleepSession(duration: duration, remaining: nil)
        }

        let expiry = defaults.double(forKey: sleepExpiryKey)
        let remaining = expiry - now.timeIntervalSinceReferenceDate
        guard remaining > 0 else { return nil }
        return PreventSleepSession(duration: duration, remaining: remaining)
    }

    private func saveSleepSession(_ duration: SleepDuration, remaining: TimeInterval?) {
        defaults.set(duration.rawValue, forKey: Self.sleepDurationKey)
        if let remaining {
            defaults.set(Date().timeIntervalSinceReferenceDate + remaining, forKey: Self.sleepExpiryKey)
        } else {
            defaults.removeObject(forKey: Self.sleepExpiryKey)
        }
    }

    private func clearSleepSession() {
        defaults.removeObject(forKey: Self.sleepDurationKey)
        defaults.removeObject(forKey: Self.sleepExpiryKey)
    }

    /// Picks up where the last launch left off. A finite session resumes with
    /// only the time it had left, so "1 hour" stays one hour of wakefulness
    /// rather than restarting on every launch.
    private func restoreSleepSession() {
        guard enabledTools.contains(.preventSleep) else { return }
        guard let session = Self.savedSleepSession(in: defaults) else {
            clearSleepSession()
            return
        }
        holdSleepAssertion(session.duration, remaining: session.remaining)
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

        if let data = defaults.data(forKey: "paperShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            paperShortcut = shortcut
        } else {
            paperShortcut = .defaultPaper
        }

        if let data = defaults.data(forKey: "scheduledCombo"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            scheduledCombo = shortcut
        } else {
            scheduledCombo = CustomShortcut(keyCode: 36, modifiers: 0) // Return
        }

        restoreSleepSession()
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
        if let data = try? JSONEncoder().encode(paperShortcut) {
            defaults.set(data, forKey: "paperShortcut")
        }
    }

    func resetToDefaults() {
        captureShortcut = .defaultCapture
        typeItShortcut = .defaultTypeIt
        moveMouseShortcut = .defaultMoveMouse
        clipboardShortcut = .defaultClipboard
        paperShortcut = .defaultPaper
    }

    func showSettingsWindow(
        hotkeyManager: HotkeyManager,
        updateManager: UpdateManager,
        clipboardStore: ClipboardStore,
        onboarding: OnboardingManager
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
            clipboardStore: clipboardStore,
            onboarding: onboarding
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 760, height: 470))
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
