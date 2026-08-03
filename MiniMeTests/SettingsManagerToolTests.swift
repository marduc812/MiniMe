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

    // MARK: - Prevent Sleep persistence

    @Test func aFreshInstallHasNoSleepSessionToRestore() {
        let settings = SettingsManager(defaults: scratchDefaults())

        #expect(settings.activeSleepDuration == nil)
    }

    @Test func anInfiniteSessionSurvivesARelaunch() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.infinite)
        settings.releaseSleepAssertion()

        let relaunched = SettingsManager(defaults: defaults)

        #expect(relaunched.activeSleepDuration == .infinite)
        relaunched.disablePreventSleep()
    }

    @Test func aFiniteSessionSurvivesARelaunch() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.oneHour)
        settings.releaseSleepAssertion()

        let relaunched = SettingsManager(defaults: defaults)

        #expect(relaunched.activeSleepDuration == .oneHour)
        relaunched.disablePreventSleep()
    }

    /// Turning it off has to stick too, otherwise the next launch would wake
    /// the Mac back up on its own.
    @Test func switchingSleepOffDoesNotComeBackAfterARelaunch() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.infinite)
        settings.disablePreventSleep()

        let relaunched = SettingsManager(defaults: defaults)

        #expect(relaunched.activeSleepDuration == nil)
    }

    @Test func aSessionIsNotRestoredWhenTheToolIsSwitchedOff() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.infinite)
        settings.releaseSleepAssertion()
        Tool.setEnabled(false, for: .preventSleep, in: defaults)

        let relaunched = SettingsManager(defaults: defaults)

        #expect(relaunched.activeSleepDuration == nil)
    }

    // MARK: - Prevent Sleep session arithmetic

    @Test func aFiniteSessionResumesWithOnlyTheTimeItHasLeft() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.oneHour)
        settings.releaseSleepAssertion()

        let session = SettingsManager.savedSleepSession(
            in: defaults,
            now: Date().addingTimeInterval(2400) // 40 minutes later
        )

        #expect(session?.duration == .oneHour)
        #expect(abs((session?.remaining ?? 0) - 1200) < 5)
    }

    @Test func aFiniteSessionThatRanOutWhileClosedIsNotRestored() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.tenMinutes)
        settings.releaseSleepAssertion()

        let session = SettingsManager.savedSleepSession(
            in: defaults,
            now: Date().addingTimeInterval(3600)
        )

        #expect(session == nil)
    }

    @Test func anInfiniteSessionNeverRunsOut() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)
        settings.enablePreventSleep(.infinite)
        settings.releaseSleepAssertion()

        let session = SettingsManager.savedSleepSession(
            in: defaults,
            now: Date().addingTimeInterval(86_400 * 30)
        )

        #expect(session == PreventSleepSession(duration: .infinite, remaining: nil))
    }
}
