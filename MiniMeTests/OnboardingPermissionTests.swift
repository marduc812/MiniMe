//
//  OnboardingPermissionTests.swift
//  MiniMeTests
//

import Testing
@testable import MiniMe

struct OnboardingPermissionTests {

    @Test func captureRequiresScreenRecording() {
        #expect(Tool.capture.permissionNeed == PermissionNeed(.screenRecording, isRequired: true))
    }

    @Test func typeItRequiresAccessibility() {
        #expect(Tool.typeIt.permissionNeed == PermissionNeed(.accessibility, isRequired: true))
    }

    @Test func moveMouseRequiresAccessibility() {
        #expect(Tool.moveMouse.permissionNeed == PermissionNeed(.accessibility, isRequired: true))
    }

    /// Clipboard works without Accessibility — picking an entry still copies it,
    /// the user just presses ⌘V themselves. The permission only buys auto-paste,
    /// so the slide must not present it as a blocker.
    @Test func clipboardWantsAccessibilityButDoesNotRequireIt() {
        #expect(Tool.clipboard.permissionNeed == PermissionNeed(.accessibility, isRequired: false))
    }

    @Test func preventSleepNeedsNoPermission() {
        #expect(Tool.preventSleep.permissionNeed == nil)
    }

    @Test func clipboardIsTheOnlyToolWithAnOptionalPermission() {
        let optional = Tool.allCases.filter { $0.permissionNeed?.isRequired == false }

        #expect(optional == [.clipboard])
    }
}
