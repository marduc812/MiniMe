//
//  OnboardingPresentationTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

/// Covers *that the window is asked for*, which is separate from what the deck
/// contains or what gets recorded.
///
/// Presentation used to be a side effect of `isPresented` changing, observed by
/// an `.onChange` on the `MenuBarExtra` scene in `MiniMeApp`. That made the
/// window conditional on the scene updating, which is not something the app
/// controls: on a fresh macOS 14 install nothing ever appeared — no slide, no
/// window, just the menu bar icon — while the same build on macOS 15 was fine.
/// These tests pin the request to the manager, where it is deterministic.
@MainActor
struct OnboardingPresentationTests {

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "OnboardingPresentationTests-\(UUID().uuidString)")!
    }

    private func manager() -> OnboardingManager {
        OnboardingManager(defaults: scratchDefaults())
    }

    // MARK: - Asking for the window

    @Test func restartingTheWizardAsksForTheWindow() {
        let manager = manager()
        var presentCount = 0
        manager.onPresent = { presentCount += 1 }

        manager.restartWizard()

        #expect(presentCount == 1)
        #expect(manager.isPresented)
    }

    @Test func presentingASingleToolAsksForTheWindow() {
        let manager = manager()
        var presentCount = 0
        manager.onPresent = { presentCount += 1 }

        manager.presentSingle(.capture)

        #expect(presentCount == 1)
        #expect(manager.isPresented)
    }

    /// The case an `isPresented` observer cannot see. `presentSingle` arriving
    /// while the wizard is already up is not a state change, so an observer
    /// fires nothing — and if the window is gone for any reason, the user is
    /// left with `isPresented == true` and nothing on screen, permanently.
    @Test func presentingWhileAlreadyPresentedStillAsksForTheWindow() {
        let manager = manager()
        manager.restartWizard()
        #expect(manager.isPresented, "precondition: already presented")

        var presentCount = 0
        manager.onPresent = { presentCount += 1 }
        manager.presentSingle(.capture)

        #expect(presentCount == 1)
    }

    /// Same blind spot on the way in: a second `restartWizard` from
    /// Settings › About while the window is already up must still put one there.
    @Test func restartingWhileAlreadyPresentedStillAsksForTheWindow() {
        let manager = manager()
        manager.restartWizard()

        var presentCount = 0
        manager.onPresent = { presentCount += 1 }
        manager.restartWizard()

        #expect(presentCount == 1)
    }

    // MARK: - Taking it down

    @Test func finishingAsksForTheWindowToGo() {
        let manager = manager()
        var dismissCount = 0
        manager.onDismiss = { dismissCount += 1 }
        manager.restartWizard()

        manager.finish()

        #expect(dismissCount == 1)
        #expect(!manager.isPresented)
    }

    /// The presenter is asked for, not required. Nothing installs it in tests of
    /// deck behaviour, and the manager must stay usable without it.
    @Test func navigationWorksWithNoPresenterInstalled() {
        let manager = manager()

        manager.restartWizard()
        manager.advance()
        manager.finish()

        #expect(!manager.isPresented)
        #expect(manager.deck.isWizard)
    }
}
