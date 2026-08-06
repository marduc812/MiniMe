//
//  AccessibilityAuthorization.swift
//  MiniMe
//

import AppKit
import ApplicationServices

/// What the app was about to do when it found Accessibility missing. The alert
/// names it, so a user is never told MiniMe wants to do something it doesn't.
enum AccessibilityPurpose: CaseIterable {
    case mouseMove

    private var need: String {
        switch self {
        case .mouseMove: return "to move the mouse pointer"
        }
    }

    var informativeText: String {
        "MiniMe needs Accessibility permission \(need). Please grant it in System Settings → Privacy & Security → Accessibility."
    }
}

/// The one place that asks the system whether MiniMe may drive other apps.
enum AccessibilityAuthorization {

    /// Whether Accessibility permission is granted, without prompting.
    ///
    /// For callers that have a working fallback and so should stay quiet about
    /// the permission — see `PasteService.paste(into:)`.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Returns true if Accessibility permission is granted. If not, shows a prompt
    /// naming `purpose` and directing the user to System Settings, then returns false.
    @discardableResult
    static func ensure(for purpose: AccessibilityPurpose) -> Bool {
        guard isTrusted else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = purpose.informativeText
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return false
        }
        return true
    }
}
