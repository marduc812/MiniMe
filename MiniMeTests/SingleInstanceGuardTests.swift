//
//  SingleInstanceGuardTests.swift
//  MiniMeTests
//

import Testing
@testable import MiniMe

struct SingleInstanceGuardTests {

    private let bundleID = "com.evaidon.minime"

    @Test func aloneMeansNoDuplicates() {
        let running = [RunningInstance(processIdentifier: 42, bundleIdentifier: bundleID)]
        #expect(SingleInstanceGuard.duplicates(
            among: running, bundleIdentifier: bundleID, ownProcessIdentifier: 42
        ).isEmpty)
    }

    /// The case behind the bug: an Xcode build launched while the installed copy
    /// is already running. Same bundle identifier, different process.
    @Test func aSecondCopyOfOurselvesIsADuplicate() {
        let running = [
            RunningInstance(processIdentifier: 42, bundleIdentifier: bundleID),
            RunningInstance(processIdentifier: 99, bundleIdentifier: bundleID),
        ]
        let duplicates = SingleInstanceGuard.duplicates(
            among: running, bundleIdentifier: bundleID, ownProcessIdentifier: 99
        )
        #expect(duplicates == [RunningInstance(processIdentifier: 42, bundleIdentifier: bundleID)])
    }

    @Test func otherAppsAreNotDuplicates() {
        let running = [
            RunningInstance(processIdentifier: 42, bundleIdentifier: "com.apple.finder"),
            RunningInstance(processIdentifier: 43, bundleIdentifier: nil),
        ]
        #expect(SingleInstanceGuard.duplicates(
            among: running, bundleIdentifier: bundleID, ownProcessIdentifier: 99
        ).isEmpty)
    }

    /// The unit tests run inside a real MiniMe process. An unconditional guard
    /// exits that host as soon as any MiniMe is running, and the suite never
    /// bootstraps — which is exactly what happened the first time this shipped.
    @Test func theTestHostIsExemptFromTheGuard() {
        #expect(SingleInstanceGuard.isTestHost(
            environment: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]
        ))
        #expect(SingleInstanceGuard.isTestHost(environment: ["XCTestSessionIdentifier": "abc"]))
        #expect(SingleInstanceGuard.isTestHost(environment: ["XCTestBundlePath": "/tmp/x.xctest"]))
    }

    @Test func anOrdinaryLaunchIsNotATestHost() {
        #expect(!SingleInstanceGuard.isTestHost(environment: [:]))
        #expect(!SingleInstanceGuard.isTestHost(environment: ["HOME": "/Users/someone"]))
    }

    /// More than two copies can pile up over a long Xcode session; the guard
    /// reports every one so the caller can defer to the oldest.
    @Test func everyOtherCopyIsReported() {
        let running = [
            RunningInstance(processIdentifier: 1, bundleIdentifier: bundleID),
            RunningInstance(processIdentifier: 2, bundleIdentifier: bundleID),
            RunningInstance(processIdentifier: 3, bundleIdentifier: bundleID),
        ]
        let duplicates = SingleInstanceGuard.duplicates(
            among: running, bundleIdentifier: bundleID, ownProcessIdentifier: 2
        )
        #expect(duplicates.map(\.processIdentifier) == [1, 3])
    }
}
