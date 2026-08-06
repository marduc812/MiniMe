//
//  OnboardingPermission.swift
//  MiniMe
//

import AppKit
import ApplicationServices
import CoreGraphics

/// A system permission a tool may want. Kept separate from `Tool` so the model
/// stays free of onboarding concerns.
enum OnboardingPermission: Equatable, CaseIterable {
    case screenRecording
    case accessibility

    var title: String {
        switch self {
        case .screenRecording: return "Screen Recording"
        case .accessibility:   return "Accessibility"
        }
    }

    /// Whether the permission is currently granted.
    ///
    /// Both checks are deliberately non-prompting. The slide shows its own
    /// explanation and Grant button, so a system dialog firing underneath it —
    /// or `TypingService.ensureAccessibilityPermission()`'s modal `NSAlert` —
    /// would be talking over the UI that is already asking the question.
    var isGranted: Bool {
        switch self {
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .accessibility:   return AXIsProcessTrusted()
        }
    }

    private var settingsURL: URL? {
        switch self {
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    func openSystemSettings() {
        guard let settingsURL else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}

/// A tool's relationship to a permission — whether it simply cannot work
/// without it, or merely works better with it.
struct PermissionNeed: Equatable {
    let permission: OnboardingPermission
    /// `false` means the tool is fully usable without the permission.
    let isRequired: Bool

    init(_ permission: OnboardingPermission, isRequired: Bool) {
        self.permission = permission
        self.isRequired = isRequired
    }
}

extension Tool {
    /// What this tool wants from the system, or `nil` if it needs nothing.
    var permissionNeed: PermissionNeed? {
        switch self {
        case .capture:
            // Nothing to OCR without it.
            return PermissionNeed(.screenRecording, isRequired: true)
        case .typeIt:
            // Synthesizing keystrokes *is* the feature.
            return PermissionNeed(.accessibility, isRequired: true)
        case .moveMouse:
            // Moving the pointer *is* the feature.
            return PermissionNeed(.accessibility, isRequired: true)
        case .clipboard:
            // Only buys auto-paste. `PasteService.paste()` already degrades to
            // leaving the entry on the pasteboard for a manual ⌘V, so history
            // and picking both work untouched without it.
            return PermissionNeed(.accessibility, isRequired: false)
        case .preventSleep, .paper:
            // Both are pure output — an IOKit assertion and a window of our own.
            return nil
        }
    }
}
