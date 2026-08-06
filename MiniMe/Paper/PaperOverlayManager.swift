//
//  PaperOverlayManager.swift
//  MiniMe
//

import AppKit

/// Holds a paper matte over every attached display.
///
/// Runtime state is a window per screen and nothing else — no timers, no event
/// taps, no polling. Once the windows are up the tool costs what a static
/// translucent layer costs, which is why the texture is rendered to a cached
/// tile rather than drawn per frame.
///
/// Whether the matte is on *is* persisted, unlike the mouse mover's armed
/// state: an effect the user can see on their screen is confusing if a relaunch
/// silently drops it.
@MainActor
final class PaperOverlayManager: ObservableObject {
    static let shared = PaperOverlayManager()

    static let activeKey = "paperActive"
    static let textureKey = "paperTexture"
    static let strengthKey = "paperStrength"

    @Published private(set) var isActive = false
    /// How many displays are currently covered — what the Settings row reports.
    @Published private(set) var coveredScreens = 0

    private var windows: [CGDirectDisplayID: PaperOverlayWindow] = [:]
    private var texture: PaperTexture = .matte
    private var strength: Int = PaperStrength.defaultValue
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - State

    /// Puts the matte back up if it was up when the app last quit. Does nothing
    /// when the tool is switched off, so a disabled tool can't resurrect itself.
    func restoreFromDefaults(toolEnabled: Bool) {
        loadConfiguration()
        guard toolEnabled, defaults.bool(forKey: Self.activeKey) else { return }
        activate()
    }

    func toggle() {
        if isActive {
            deactivate()
        } else {
            loadConfiguration()
            activate()
        }
    }

    func activate() {
        isActive = true
        defaults.set(true, forKey: Self.activeKey)
        reconcile()
    }

    func deactivate() {
        isActive = false
        defaults.set(false, forKey: Self.activeKey)
        reconcile()
    }

    /// Tears the matte down without recording that the user wanted it off, so
    /// switching the tool back on restores what they had.
    func suspend() {
        isActive = false
        reconcile()
    }

    // MARK: - Configuration

    /// Applies a new texture or strength to the live windows. Cheap enough to
    /// call from a slider drag: it swaps a cached tile and an alpha value.
    func apply(texture: PaperTexture, strength: Int) {
        self.texture = texture
        self.strength = strength
        let alpha = CGFloat(PaperStrength.alpha(for: strength))
        for window in windows.values {
            window.apply(texture: texture, alpha: alpha)
        }
    }

    private func loadConfiguration() {
        if let raw = defaults.string(forKey: Self.textureKey),
           let stored = PaperTexture(rawValue: raw) {
            texture = stored
        }
        if defaults.object(forKey: Self.strengthKey) != nil {
            strength = defaults.integer(forKey: Self.strengthKey)
        }
    }

    // MARK: - Windows

    @objc private func screenParametersChanged() {
        Task { @MainActor in reconcile() }
    }

    /// Brings the windows in line with the attached displays.
    ///
    /// Only the difference is acted on: `didChangeScreenParametersNotification`
    /// also fires for things that don't change the screen list, and rebuilding
    /// every window on those would flicker the matte.
    private func reconcile() {
        let screens = isActive ? NSScreen.screens : []
        let attached = Set(screens.map(\.displayID))
        let plan = PaperWindowPlan.reconciling(existing: Set(windows.keys), attached: attached)

        for displayID in plan.remove {
            windows[displayID]?.orderOut(nil)
            windows[displayID] = nil
        }

        let alpha = CGFloat(PaperStrength.alpha(for: strength))
        for screen in screens {
            let displayID = screen.displayID
            if plan.add.contains(displayID) {
                let window = PaperOverlayWindow(screen: screen, texture: texture, alpha: alpha)
                windows[displayID] = window
                window.orderFrontRegardless()
            } else {
                // A display that kept its ID may still have changed resolution
                // or moved in the arrangement.
                windows[displayID]?.matchFrame(of: screen)
            }
        }

        coveredScreens = windows.count
    }

    // MARK: - Capture

    /// Window numbers of the live overlays, for `ScreenCaptureKit` to exclude.
    var windowNumbers: Set<Int> {
        Set(windows.values.map(\.windowNumber))
    }
}
