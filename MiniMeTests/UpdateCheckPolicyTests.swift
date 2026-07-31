//
//  UpdateCheckPolicyTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct UpdateCheckPolicyTests {

    // MARK: - Version comparison

    @Test func patchBumpIsNewer() {
        #expect(UpdateCheckPolicy.isVersionNewer("1.0.13", than: "1.0.12"))
    }

    @Test func doubleDigitPatchBeatsSingleDigit() {
        // String comparison would get this backwards: "1.0.9" > "1.0.13".
        #expect(UpdateCheckPolicy.isVersionNewer("1.0.13", than: "1.0.9"))
        #expect(!UpdateCheckPolicy.isVersionNewer("1.0.9", than: "1.0.13"))
    }

    @Test func sameVersionIsNotNewer() {
        #expect(!UpdateCheckPolicy.isVersionNewer("1.0.12", than: "1.0.12"))
    }

    @Test func olderVersionIsNotNewer() {
        #expect(!UpdateCheckPolicy.isVersionNewer("1.0.11", than: "1.0.12"))
    }

    @Test func minorBumpBeatsPatchesOfPreviousMinor() {
        #expect(UpdateCheckPolicy.isVersionNewer("1.1", than: "1.0.99"))
    }

    @Test func missingComponentsCountAsZero() {
        #expect(!UpdateCheckPolicy.isVersionNewer("1.0", than: "1.0.0"))
        #expect(UpdateCheckPolicy.isVersionNewer("1.0.1", than: "1.0"))
    }

    // MARK: - Daily throttle

    @Test func checksWhenNeverCheckedBefore() {
        #expect(UpdateCheckPolicy.shouldCheck(
            lastCheck: nil, now: Date(), automaticChecksEnabled: true
        ))
    }

    @Test func skipsWithinTheDay() {
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        #expect(!UpdateCheckPolicy.shouldCheck(
            lastCheck: hourAgo, now: now, automaticChecksEnabled: true
        ))
    }

    @Test func checksExactlyOnTheBoundary() {
        let now = Date()
        let dayAgo = now.addingTimeInterval(-UpdateCheckPolicy.checkInterval)
        #expect(UpdateCheckPolicy.shouldCheck(
            lastCheck: dayAgo, now: now, automaticChecksEnabled: true
        ))
    }

    @Test func checksJustBeforeTheBoundary() {
        let now = Date()
        let almostADay = now.addingTimeInterval(-UpdateCheckPolicy.checkInterval + 1)
        #expect(!UpdateCheckPolicy.shouldCheck(
            lastCheck: almostADay, now: now, automaticChecksEnabled: true
        ))
    }

    /// The Mac slept through several intervals; the first tick after waking
    /// should still check rather than wait out another full day.
    @Test func checksAfterALongSleep() {
        let now = Date()
        let threeDaysAgo = now.addingTimeInterval(-3 * UpdateCheckPolicy.checkInterval)
        #expect(UpdateCheckPolicy.shouldCheck(
            lastCheck: threeDaysAgo, now: now, automaticChecksEnabled: true
        ))
    }

    @Test func neverChecksWhenAutomaticChecksAreOff() {
        #expect(!UpdateCheckPolicy.shouldCheck(
            lastCheck: nil, now: Date(), automaticChecksEnabled: false
        ))
        #expect(!UpdateCheckPolicy.shouldCheck(
            lastCheck: Date(timeIntervalSince1970: 0), now: Date(), automaticChecksEnabled: false
        ))
    }

    // MARK: - Notify once per version

    @Test func notifiesForAnUnseenNewerVersion() {
        #expect(UpdateCheckPolicy.shouldNotify(
            latest: "1.0.13", current: "1.0.12", lastNotified: nil
        ))
    }

    @Test func staysSilentForAVersionAlreadyNotified() {
        #expect(!UpdateCheckPolicy.shouldNotify(
            latest: "1.0.13", current: "1.0.12", lastNotified: "1.0.13"
        ))
    }

    @Test func notifiesAgainWhenAnEvenNewerVersionLands() {
        #expect(UpdateCheckPolicy.shouldNotify(
            latest: "1.0.14", current: "1.0.12", lastNotified: "1.0.13"
        ))
    }

    @Test func staysSilentWhenAlreadyUpToDate() {
        #expect(!UpdateCheckPolicy.shouldNotify(
            latest: "1.0.12", current: "1.0.12", lastNotified: nil
        ))
    }

    /// Running a build newer than the latest release — the maintainer's own
    /// case — must never notify.
    @Test func staysSilentWhenAheadOfTheLatestRelease() {
        #expect(!UpdateCheckPolicy.shouldNotify(
            latest: "1.0.11", current: "1.0.12", lastNotified: nil
        ))
    }

    @Test func staysSilentWithNoFetchedVersion() {
        #expect(!UpdateCheckPolicy.shouldNotify(
            latest: nil, current: "1.0.12", lastNotified: nil
        ))
    }

    /// Downgrading after having been notified about a version you then
    /// installed and rolled back from should notify again.
    @Test func notifiesAgainAfterADowngrade() {
        #expect(UpdateCheckPolicy.shouldNotify(
            latest: "1.0.14", current: "1.0.10", lastNotified: "1.0.13"
        ))
    }
}
