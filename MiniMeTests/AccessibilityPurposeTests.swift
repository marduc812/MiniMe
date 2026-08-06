//
//  AccessibilityPurposeTests.swift
//  MiniMeTests
//

import Testing
@testable import MiniMe

struct AccessibilityPurposeTests {

    /// The Mouse Mover used to borrow a shared wording and tell the user MiniMe
    /// wanted to "simulate typing" — for a tool that never types.
    @Test func mouseMoveDoesNotClaimToBeTyping() {
        let text = AccessibilityPurpose.mouseMove.informativeText
        #expect(!text.lowercased().contains("typ"))
        #expect(text.contains("mouse"))
    }

    @Test func everyPurposePointsAtTheRightSettingsPane() {
        for purpose in AccessibilityPurpose.allCases {
            #expect(purpose.informativeText.contains("Privacy & Security → Accessibility"))
        }
    }
}
