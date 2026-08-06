//
//  RetiredPreferencesTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct RetiredPreferencesTests {

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "RetiredPreferencesTests-\(UUID().uuidString)")!
    }

    @Test func removesEveryRetiredKey() {
        let defaults = scratchDefaults()
        for key in RetiredPreferences.keys {
            defaults.set("stale", forKey: key)
        }

        RetiredPreferences.removeAll(from: defaults)

        for key in RetiredPreferences.keys {
            #expect(defaults.object(forKey: key) == nil, "\(key) survived the sweep")
        }
    }

    /// The sweep runs against the same domain every live preference lives in.
    /// One mistyped entry in the list and it deletes a setting the user still
    /// uses — silently, on the next launch.
    @Test func leavesLivePreferencesAlone() {
        let defaults = scratchDefaults()
        let live: [String: Any] = [
            "captureShortcut": Data([0x01]),
            "clipboardShortcut": Data([0x02]),
            "paperShortcut": Data([0x03]),
            "clipboardMaxEntries": 200,
            "clipboardPickBehavior": "copyAndPaste",
            "mouseMoverMinSeconds": 5,
            PaperOverlayManager.textureKey: PaperTexture.vellum.rawValue,
            PaperOverlayManager.strengthKey: 70,
            PaperOverlayManager.activeKey: true,
            "preventSleepDuration": SleepDuration.oneHour.rawValue,
            Tool.capture.defaultsKey: false,
        ]
        for (key, value) in live {
            defaults.set(value, forKey: key)
        }

        RetiredPreferences.removeAll(from: defaults)

        for key in live.keys {
            #expect(defaults.object(forKey: key) != nil, "\(key) was swept away")
        }
    }

    @Test func aFreshInstallHasNothingToSweep() {
        let defaults = scratchDefaults()

        RetiredPreferences.removeAll(from: defaults)

        for key in RetiredPreferences.keys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    /// The sweep runs on every launch, not once behind a flag, so running it
    /// against an already-clean domain has to stay a no-op.
    @Test func sweepingTwiceIsHarmless() {
        let defaults = scratchDefaults()
        defaults.set(3, forKey: "typeItCountdownDuration")
        defaults.set(200, forKey: "clipboardMaxEntries")

        RetiredPreferences.removeAll(from: defaults)
        RetiredPreferences.removeAll(from: defaults)

        #expect(defaults.object(forKey: "typeItCountdownDuration") == nil)
        #expect(defaults.integer(forKey: "clipboardMaxEntries") == 200)
    }

    @Test func theListHasNoDuplicates() {
        #expect(Set(RetiredPreferences.keys).count == RetiredPreferences.keys.count)
    }
}

@MainActor
struct RetiredPreferenceSweepAtLaunchTests {

    /// The sweep is worthless if nothing calls it — this is the wiring.
    @Test func buildingSettingsClearsPreferencesLeftByRemovedTools() {
        let defaults = UserDefaults(suiteName: "RetiredSweep-\(UUID().uuidString)")!
        defaults.set(5, forKey: "typeItCountdownDuration")
        defaults.set("continue please", forKey: "scheduledText")
        defaults.set(Data([0x01]), forKey: "typeItShortcut")

        _ = SettingsManager(defaults: defaults)

        #expect(defaults.object(forKey: "typeItCountdownDuration") == nil)
        #expect(defaults.object(forKey: "scheduledText") == nil)
        #expect(defaults.object(forKey: "typeItShortcut") == nil)
    }

    /// Sweeping must not disturb the settings loaded in the same initializer.
    @Test func theSweepLeavesTheShortcutsItLoadsIntact() {
        let defaults = UserDefaults(suiteName: "RetiredSweep-\(UUID().uuidString)")!
        let custom = CustomShortcut(keyCode: 12, modifiers: 1179648)
        defaults.set(try! JSONEncoder().encode(custom), forKey: "captureShortcut")
        defaults.set("stale", forKey: "scheduledText")

        let settings = SettingsManager(defaults: defaults)

        #expect(settings.captureShortcut == custom)
        #expect(defaults.object(forKey: "scheduledText") == nil)
    }
}
