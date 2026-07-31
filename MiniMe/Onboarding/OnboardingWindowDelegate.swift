//
//  OnboardingWindowDelegate.swift
//  MiniMe
//

import AppKit

/// Notices the setup window being closed with its title bar button, so an early
/// exit is recorded the same way pressing Done is.
final class OnboardingWindowDelegate: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
