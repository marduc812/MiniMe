//
//  ToolTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct ToolTests {

    /// Each test gets its own defaults domain so cases can't leak into each other.
    private func scratchDefaults() -> UserDefaults {
        let suite = "ToolTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - Cases

    @Test func hasExactlyTheFiveToggleableTools() {
        #expect(Set(Tool.allCases) == [.capture, .clipboard, .moveMouse, .preventSleep, .paper])
    }

    @Test func defaultsKeysAreNamespacedAndUnique() {
        let keys = Tool.allCases.map(\.defaultsKey)

        #expect(Set(keys).count == Tool.allCases.count)
        #expect(keys.allSatisfy { $0.hasPrefix("tool.") })
    }

    @Test func everyToolHasATitleAndIcon() {
        for tool in Tool.allCases {
            #expect(!tool.title.isEmpty)
            #expect(!tool.icon.isEmpty)
        }
    }

    // MARK: - Persistence

    @Test func absentKeyMeansEnabled() {
        let defaults = scratchDefaults()

        #expect(Tool.enabledSet(from: defaults) == Set(Tool.allCases))
    }

    @Test func disablingAToolRemovesItFromTheEnabledSet() {
        let defaults = scratchDefaults()

        Tool.setEnabled(false, for: .moveMouse, in: defaults)

        let enabled = Tool.enabledSet(from: defaults)
        #expect(!enabled.contains(.moveMouse))
        #expect(enabled.contains(.capture))
    }

    @Test func reEnablingAToolRestoresIt() {
        let defaults = scratchDefaults()

        Tool.setEnabled(false, for: .clipboard, in: defaults)
        Tool.setEnabled(true, for: .clipboard, in: defaults)

        #expect(Tool.enabledSet(from: defaults).contains(.clipboard))
    }

    @Test func disablingOneToolLeavesTheOthersEnabled() {
        let defaults = scratchDefaults()

        Tool.setEnabled(false, for: .preventSleep, in: defaults)

        #expect(Tool.enabledSet(from: defaults) == Set(Tool.allCases).subtracting([.preventSleep]))
    }

    // MARK: - Migration off `clipboardHistoryEnabled`

    @Test func legacyClipboardHistoryDisabledMigratesToClipboardOff() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: "clipboardHistoryEnabled")

        Tool.migrateLegacyKeys(in: defaults)

        #expect(!Tool.enabledSet(from: defaults).contains(.clipboard))
        #expect(defaults.object(forKey: "clipboardHistoryEnabled") == nil)
    }

    @Test func legacyClipboardHistoryEnabledLeavesClipboardOn() {
        let defaults = scratchDefaults()
        defaults.set(true, forKey: "clipboardHistoryEnabled")

        Tool.migrateLegacyKeys(in: defaults)

        #expect(Tool.enabledSet(from: defaults).contains(.clipboard))
        #expect(defaults.object(forKey: "clipboardHistoryEnabled") == nil)
    }

    @Test func migrationIsANoOpWhenTheLegacyKeyIsAbsent() {
        let defaults = scratchDefaults()

        Tool.migrateLegacyKeys(in: defaults)

        #expect(Tool.enabledSet(from: defaults) == Set(Tool.allCases))
    }

    @Test func migrationDoesNotClobberAnAlreadyMigratedPreference() {
        let defaults = scratchDefaults()
        // User already disabled Clipboard under the new key, and a stale legacy
        // key says it was on. The new key must win.
        Tool.setEnabled(false, for: .clipboard, in: defaults)
        defaults.set(true, forKey: "clipboardHistoryEnabled")

        Tool.migrateLegacyKeys(in: defaults)

        #expect(!Tool.enabledSet(from: defaults).contains(.clipboard))
    }
}
