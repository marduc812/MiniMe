//
//  SingleInstanceGuard.swift
//  MiniMe
//

import AppKit

/// A running process reduced to what the duplicate check needs.
/// `NSRunningApplication` can't be built in a test, so the decision is made
/// against this instead and the real query maps into it.
struct RunningInstance: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
}

/// Keeps a second copy of MiniMe from launching alongside the first.
///
/// Two copies both call `RegisterEventHotKey` for the same combos and whichever
/// wins answers them. That stays invisible until the two copies are signed
/// differently — an Xcode build next to the installed one — because the
/// Accessibility grant in TCC is bound to a code requirement only one signature
/// satisfies. The other copy answers the hotkey as a process macOS considers
/// untrusted, so the user gets a permission alert for a permission they granted.
///
/// First one in wins; later launches surface it and step aside.
enum SingleInstanceGuard {

    /// Instances of the same app other than the caller's own process.
    static func duplicates(
        among running: [RunningInstance],
        bundleIdentifier: String,
        ownProcessIdentifier: pid_t
    ) -> [RunningInstance] {
        running.filter {
            $0.bundleIdentifier == bundleIdentifier && $0.processIdentifier != ownProcessIdentifier
        }
    }

    /// Whether the app was launched as an XCTest host rather than by the user.
    ///
    /// The unit tests run inside a real MiniMe process, so a guard that fired
    /// here would exit the test host whenever a copy of MiniMe happened to be
    /// running — the whole suite fails to bootstrap.
    static func isTestHost(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    /// Passed by the UI tests so the app under test keeps the guard switched off.
    ///
    /// Deliberately not `-`-prefixed: macOS folds `-key value` launch arguments
    /// into `NSArgumentDomain`, where the name could shadow one of the app's
    /// `@AppStorage` keys.
    static let uiTestLaunchArgument = "MINIME_UI_TESTING"

    /// Whether the UI test runner launched this process.
    ///
    /// `isTestHost` can't answer this. UI tests drive MiniMe as its own process
    /// through `XCUIApplication`, which does not carry the XCTest environment a
    /// unit test host has — so the guard was live inside the app under test, and
    /// any other copy running on the machine (the installed one, usually) made
    /// it exit before the runner could see it. Every UI test then waited out its
    /// timeout.
    static func isUITestRun(arguments: [String]) -> Bool {
        arguments.contains(uiTestLaunchArgument)
    }

    /// Exits the process if another MiniMe already holds the menu bar, bringing
    /// that one forward first so the launch still shows the user something.
    ///
    /// Call before any hotkey is registered — once both processes have claimed
    /// the same combo the damage is done.
    @MainActor
    static func yieldToRunningInstance() {
        guard !isTestHost(environment: ProcessInfo.processInfo.environment) else { return }
        guard !isUITestRun(arguments: ProcessInfo.processInfo.arguments) else { return }
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let others = duplicates(
            among: running.map {
                RunningInstance(processIdentifier: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier)
            },
            bundleIdentifier: bundleID,
            ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        guard let existing = others.first else { return }

        // Printed rather than shown: a user double-clicking the app wants the
        // menu, not a dialog. The line is for whoever is running from Xcode and
        // wondering why the build exited immediately.
        print("[SingleInstanceGuard] MiniMe is already running (pid \(existing.processIdentifier)) — quit it first. Exiting.")

        NSRunningApplication(processIdentifier: existing.processIdentifier)?.activate()

        // The run loop hasn't started and nothing has been initialized, so there
        // is no state to unwind — `NSApp.terminate` has no work to do here.
        exit(0)
    }
}
