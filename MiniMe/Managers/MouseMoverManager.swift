//
//  MouseMoverManager.swift
//  MiniMe
//

import AppKit

/// Periodically drifts the cursor to a random point inside a 600×600 box centered on
/// wherever the cursor was when armed. Waits a random interval between moves (with a
/// minimum floor) so there's always a quiet window to grab the mouse and stop it.
/// Runtime (armed) state is in-memory only — quitting cancels it.
@MainActor
final class MouseMoverManager: ObservableObject {
    static let shared = MouseMoverManager()
    private init() {}

    /// Side length of the square the cursor is kept within.
    static let boxSize: CGFloat = 600

    @Published private(set) var isArmed = false
    @Published private(set) var nextMoveDate: Date?

    private var timer: Timer?
    private var center: NSPoint = .zero      // AppKit global coords, captured at arm time
    private var minInterval: TimeInterval = 0
    private var maxInterval: TimeInterval = 0

    /// Arms the mover. Requires Accessibility permission (prompts and returns without arming
    /// if it's missing). Intervals are seconds; `max` is clamped up to `min` if smaller.
    func arm(minInterval: TimeInterval, maxInterval: TimeInterval) {
        guard minInterval > 0 else { return }
        guard TypingService.shared.ensureAccessibilityPermission(for: .mouseMove) else { return }

        disarm()
        center = NSEvent.mouseLocation
        self.minInterval = minInterval
        self.maxInterval = max(maxInterval, minInterval)
        schedule()
        isArmed = true
    }

    func disarm() {
        timer?.invalidate()
        timer = nil
        nextMoveDate = nil
        isArmed = false
    }

    /// Toggles the mover using the persisted interval settings. Used by the menu and global hotkey.
    func toggle() {
        if isArmed {
            disarm()
        } else {
            let minSeconds = UserDefaults.standard.object(forKey: "mouseMoverMinSeconds") as? Int ?? 5
            let maxSeconds = UserDefaults.standard.object(forKey: "mouseMoverMaxSeconds") as? Int ?? 12
            arm(minInterval: Double(minSeconds), maxInterval: Double(maxSeconds))
        }
    }

    private func schedule() {
        let interval = TimeInterval.random(in: minInterval...maxInterval)
        nextMoveDate = Date().addingTimeInterval(interval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.fire() }
        }
    }

    private func fire() {
        let target = Self.randomTarget(around: center)
        Task.detached { await Self.glide(to: target) }
        schedule()
    }

    /// Picks a random point within the 600×600 box around `center` (AppKit global coords),
    /// clamped to the screen that contains the center so the cursor never leaves the display.
    private static func randomTarget(around center: NSPoint) -> NSPoint {
        let half = boxSize / 2
        var x = CGFloat.random(in: (center.x - half)...(center.x + half))
        var y = CGFloat.random(in: (center.y - half)...(center.y + half))

        let screen = NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
            ?? NSScreen.main
        if let frame = screen?.frame {
            let margin: CGFloat = 2
            x = min(max(x, frame.minX + margin), frame.maxX - margin)
            y = min(max(y, frame.minY + margin), frame.maxY - margin)
        }
        return NSPoint(x: x, y: y)
    }

    /// Smoothly moves the cursor to `target` (AppKit global coords) by posting a short series
    /// of interpolated mouse-moved events — real movement, which registers as activity against
    /// an idle timer. Runs off the main thread.
    private static func glide(to target: NSPoint) async {
        let source = CGEventSource(stateID: .hidSystemState)
        let endCG = quartzPoint(from: target)
        let startCG = CGEvent(source: nil)?.location ?? endCG

        let steps = 24
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let eased = t * t * (3 - 2 * t)   // smoothstep
            let point = CGPoint(
                x: startCG.x + (endCG.x - startCG.x) * eased,
                y: startCG.y + (endCG.y - startCG.y) * eased
            )
            CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                    mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
            try? await Task.sleep(nanoseconds: 10_000_000)   // ~10ms/step → ~0.24s glide
        }
    }

    /// Converts an AppKit global point (bottom-left origin, y-up) to a Quartz global point
    /// (top-left origin, y-down) as used by CGEvent.
    private static func quartzPoint(from point: NSPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? point.y
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
