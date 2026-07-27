//
//  SettingsManagerToolTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

@MainActor
struct SettingsManagerToolTests {

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SettingsManagerToolTests-\(UUID().uuidString)")!
    }

    // MARK: - Reading enablement

    @Test func everyToolIsEnabledOnAFreshInstall() {
        let settings = SettingsManager(defaults: scratchDefaults())

        #expect(settings.enabledTools == Set(Tool.allCases))
    }

    @Test func aToolDisabledInDefaultsLoadsAsDisabled() {
        let defaults = scratchDefaults()
        Tool.setEnabled(false, for: .typeIt, in: defaults)

        let settings = SettingsManager(defaults: defaults)

        #expect(!settings.isEnabled(.typeIt))
        #expect(settings.isEnabled(.capture))
    }

    @Test func legacyClipboardHistoryPreferenceIsHonouredOnLoad() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: "clipboardHistoryEnabled")

        let settings = SettingsManager(defaults: defaults)

        #expect(!settings.isEnabled(.clipboard))
    }

    // MARK: - Writing enablement

    @Test func setEnabledPersistsAndUpdatesThePublishedSet() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)

        settings.setEnabled(.moveMouse, false)

        #expect(!settings.enabledTools.contains(.moveMouse))
        #expect(!Tool.enabledSet(from: defaults).contains(.moveMouse))
    }

    @Test func shortcutSetCarriesTheEnabledTools() {
        let settings = SettingsManager(defaults: scratchDefaults())

        settings.setEnabled(.clipboard, false)

        #expect(!settings.shortcutSet.isEnabled(.clipboard))
        #expect(settings.shortcutSet.isEnabled(.capture))
    }

    // MARK: - Prevent Sleep teardown

    /// Leaving the IOKit assertion held while removing the only UI that can
    /// release it would keep the Mac awake indefinitely.
    @Test func disablingPreventSleepReleasesAnActiveAssertion() {
        let settings = SettingsManager(defaults: scratchDefaults())
        settings.enablePreventSleep(.infinite)
        #expect(settings.activeSleepDuration != nil, "precondition: assertion is held")

        settings.setEnabled(.preventSleep, false)

        #expect(settings.activeSleepDuration == nil)
    }

    @Test func disablingAnotherToolLeavesPreventSleepRunning() {
        let settings = SettingsManager(defaults: scratchDefaults())
        settings.enablePreventSleep(.infinite)

        settings.setEnabled(.capture, false)

        #expect(settings.activeSleepDuration != nil)
        settings.disablePreventSleep()
    }
}
