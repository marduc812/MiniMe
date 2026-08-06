//
//  OnboardingCompletionTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

@MainActor
struct OnboardingCompletionTests {

    private func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "OnboardingCompletionTests-\(UUID().uuidString)")!
    }

    // MARK: - First launch

    @Test func aFreshInstallShowsTheWizard() {
        let manager = OnboardingManager(defaults: scratchDefaults())

        #expect(manager.shouldPresentOnLaunch)
    }

    @Test func aFinishedWizardDoesNotComeBackOnTheNextLaunch() {
        let defaults = scratchDefaults()

        OnboardingManager(defaults: defaults).finish()

        #expect(!OnboardingManager(defaults: defaults).shouldPresentOnLaunch)
    }

    // MARK: - Early close

    /// Closing the window partway through is a completion, not a cancellation —
    /// the user has seen the tools they have seen and decided about them.
    @Test func closingPartwayThroughStillCountsAsFinished() {
        let defaults = scratchDefaults()
        let manager = OnboardingManager(defaults: defaults)
        manager.advance()
        manager.advance()

        manager.finish()

        #expect(!OnboardingManager(defaults: defaults).shouldPresentOnLaunch)
        #expect(!manager.isPresented)
    }

    /// Every switch writes through `SettingsManager` the moment it is flipped,
    /// so there is no pending state for an early close to discard. Tools the
    /// user never reached keep the default.
    @Test func choicesMadeBeforeAnEarlyCloseSurviveAndTheRestStayOn() {
        let defaults = scratchDefaults()
        let settings = SettingsManager(defaults: defaults)

        settings.setEnabled(.capture, false)
        settings.setEnabled(.paper, false)
        OnboardingManager(defaults: defaults).finish()

        let reloaded = SettingsManager(defaults: defaults)
        #expect(!reloaded.isEnabled(.capture))
        #expect(!reloaded.isEnabled(.paper))
        #expect(reloaded.isEnabled(.clipboard))
        #expect(reloaded.isEnabled(.moveMouse))
        #expect(reloaded.isEnabled(.preventSleep))
    }

    // MARK: - Re-running

    @Test func restartingTheWizardShowsItFromTheWelcomeSlide() {
        let manager = OnboardingManager(defaults: scratchDefaults())
        manager.advance()
        manager.finish()

        manager.restartWizard()

        #expect(manager.isPresented)
        #expect(manager.deck.current == .welcome)
        #expect(manager.deck.isWizard)
    }

    // MARK: - Single-slide mode

    @Test func presentingASingleToolSkipsTheRestOfTheDeck() {
        let manager = OnboardingManager(defaults: scratchDefaults())

        manager.presentSingle(.capture)

        #expect(manager.isPresented)
        #expect(manager.deck.current == .tool(.capture))
        #expect(!manager.deck.isWizard)
    }

    /// A fresh install can be shown a single slide before it has ever been
    /// shown the wizard: press the capture hotkey on a machine with no Screen
    /// Recording grant and `presentSingle(.capture)` puts that one slide up.
    /// Closing it answered a permission question, not the setup question — so
    /// the wizard is still owed on the next launch.
    ///
    /// Regression: `finish()` recorded completion for every deck, so dismissing
    /// that one slide marked first-run setup done on a machine that had never
    /// seen it. Setup then never appeared again and had to be dug out of
    /// Settings › About › Run Setup Again.
    @Test func singleSlideModeOnAFreshInstallStillOwesTheWizard() {
        let defaults = scratchDefaults()
        let manager = OnboardingManager(defaults: defaults)
        #expect(manager.shouldPresentOnLaunch, "precondition: nothing has run yet")

        manager.presentSingle(.capture)
        manager.finish()

        #expect(OnboardingManager(defaults: defaults).shouldPresentOnLaunch)
    }

    /// Fixing a revoked permission is not first-run setup, so it must not
    /// resurrect the wizard on the next launch.
    @Test func singleSlideModeDoesNotReopenTheWizardLater() {
        let defaults = scratchDefaults()
        OnboardingManager(defaults: defaults).finish()

        let manager = OnboardingManager(defaults: defaults)
        manager.presentSingle(.capture)
        manager.finish()

        #expect(!OnboardingManager(defaults: defaults).shouldPresentOnLaunch)
    }

    // MARK: - The optional Clipboard prompt

    @Test func theClipboardAccessibilityPromptStartsVisible() {
        let manager = OnboardingManager(defaults: scratchDefaults())

        #expect(!manager.isClipboardPromptDismissed)
    }

    /// "Not now" answers the question for good — including on a later
    /// "Run Setup Again…", which should not re-ask something already declined.
    @Test func dismissingTheClipboardPromptSticksAcrossARestart() {
        let defaults = scratchDefaults()
        let manager = OnboardingManager(defaults: defaults)

        manager.dismissClipboardPrompt()
        manager.restartWizard()

        #expect(manager.isClipboardPromptDismissed)
        #expect(OnboardingManager(defaults: defaults).isClipboardPromptDismissed)
    }
}
