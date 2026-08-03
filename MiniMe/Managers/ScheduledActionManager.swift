//
//  ScheduledActionManager.swift
//  MiniMe
//

import SwiftUI

enum ScheduleUnit: String, CaseIterable, Identifiable {
    case seconds = "Seconds"
    case minutes = "Minutes"
    case hours   = "Hours"

    var id: String { rawValue }

    var multiplier: TimeInterval {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours:   return 3600
        }
    }
}

/// Runs a single armed schedule that types text and/or sends a key combo after a delay,
/// optionally repeating. Runtime (armed) state is in-memory only — quitting cancels it.
@MainActor
final class ScheduledActionManager: ObservableObject {
    static let shared = ScheduledActionManager()
    private init() {}

    @Published private(set) var isArmed = false
    @Published private(set) var nextFireDate: Date?

    private var timer: Timer?
    private var text = ""
    private var combo: CustomShortcut?
    private var interval: TimeInterval = 0
    private var repeats = false

    /// Arms the schedule. Requires Accessibility permission (prompts and returns without
    /// arming if it's missing). A non-positive interval is ignored.
    func arm(text: String, combo: CustomShortcut?, interval: TimeInterval, repeats: Bool) {
        guard interval > 0 else { return }
        guard TypingService.shared.ensureAccessibilityPermission(for: .scheduledAction) else { return }

        disarm()
        self.text = text
        self.combo = combo
        self.interval = interval
        self.repeats = repeats
        schedule()
        isArmed = true
    }

    func disarm() {
        timer?.invalidate()
        timer = nil
        nextFireDate = nil
        isArmed = false
    }

    private func schedule() {
        nextFireDate = Date().addingTimeInterval(interval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.fire() }
        }
    }

    private func fire() {
        TypingService.shared.fireScheduledAction(text: text, combo: combo)
        if repeats {
            schedule()
        } else {
            disarm()
        }
    }
}
