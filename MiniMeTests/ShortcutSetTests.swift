//
//  ShortcutSetTests.swift
//  MiniMeTests
//

import Testing
@testable import MiniMe

struct ShortcutSetTests {

    private func makeSet(enabled: Set<Tool>) -> ShortcutSet {
        ShortcutSet(
            capture: .defaultCapture,
            typeIt: .defaultTypeIt,
            moveMouse: .defaultMoveMouse,
            clipboard: .defaultClipboard,
            enabledTools: enabled
        )
    }

    /// `MiniMeApp` re-registers hotkeys from `.onChange(of: settingsManager.shortcutSet)`,
    /// which only fires when the set compares unequal. If enablement didn't affect
    /// equality, turning a tool off would leave its hotkey live.
    @Test func setsDifferingOnlyInEnabledToolsAreUnequal() {
        let all = makeSet(enabled: Set(Tool.allCases))
        let withoutClipboard = makeSet(enabled: Set(Tool.allCases).subtracting([.clipboard]))

        #expect(all != withoutClipboard)
    }

    @Test func setsWithIdenticalShortcutsAndEnablementAreEqual() {
        #expect(makeSet(enabled: [.capture]) == makeSet(enabled: [.capture]))
    }
}
