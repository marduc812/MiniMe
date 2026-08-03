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

    /// The UI tests launch MiniMe as its own process, which carries none of the
    /// XCTest environment above — so they hand the exemption over explicitly.
    /// Without this the guard fired inside the app under test and every UI test
    /// timed out waiting for a window that had already exited.
    @Test func theAppUnderUITestIsExemptFromTheGuard() {
        #expect(SingleInstanceGuard.isUITestRun(
            arguments: ["/path/to/MiniMe", SingleInstanceGuard.uiTestLaunchArgument]
        ))
    }

    @Test func anOrdinaryLaunchIsNotAUITestRun() {
        #expect(!SingleInstanceGuard.isUITestRun(arguments: []))
        #expect(!SingleInstanceGuard.isUITestRun(arguments: ["/path/to/MiniMe"]))
        #expect(!SingleInstanceGuard.isUITestRun(arguments: ["/path/to/MiniMe", "-psn_0_12345"]))
    }

    /// Pins the literal. `XCUIApplication.miniMe()` spells the same string out
    /// on the UI test side — a target can't import the app module — so renaming
    /// it here alone would silently arm the guard against the app under test.
    ///
    /// The leading character matters too: `NSArgumentDomain` only picks up
    /// `-`-prefixed names, so this one can't shadow an `@AppStorage` key.
    @Test func theUITestFlagIsTheOneTheUITestsPass() {
        #expect(SingleInstanceGuard.uiTestLaunchArgument == "MINIME_UI_TESTING")
        #expect(!SingleInstanceGuard.uiTestLaunchArgument.hasPrefix("-"))
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
