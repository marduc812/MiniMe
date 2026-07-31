//
//  OnboardingDeckTests.swift
//  MiniMeTests
//

import Testing
@testable import MiniMe

struct OnboardingDeckTests {

    // MARK: - Composition

    @Test func theWizardOpensOnTheWelcomeSlideAndEndsOnDone() {
        let deck = OnboardingDeck()

        #expect(deck.slides.first == .welcome)
        #expect(deck.slides.last == .done)
    }

    /// `Tool.swift` claims to be the single source of truth for which tools
    /// exist. The deck has to honour that, or adding a sixth tool silently
    /// leaves it undocumented.
    @Test func theWizardHasASlideForEveryTool() {
        let deck = OnboardingDeck()

        let tools = deck.slides.compactMap { slide -> Tool? in
            if case .tool(let tool) = slide { return tool }
            return nil
        }

        #expect(tools == Tool.allCases)
    }

    @Test func theWizardIsTheToolsPlusWelcomeAndDone() {
        #expect(OnboardingDeck().slides.count == Tool.allCases.count + 2)
    }

    @Test func slideIdentifiersAreUnique() {
        let ids = OnboardingDeck().slides.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Navigation

    @Test func theDeckStartsAtTheFirstSlide() {
        let deck = OnboardingDeck()

        #expect(deck.current == .welcome)
        #expect(!deck.canGoBack)
    }

    @Test func advancingMovesToTheNextSlide() {
        var deck = OnboardingDeck()

        deck.advance()

        #expect(deck.current == .tool(Tool.allCases[0]))
        #expect(deck.canGoBack)
    }

    @Test func goingBackReturnsToThePreviousSlide() {
        var deck = OnboardingDeck()

        deck.advance()
        deck.goBack()

        #expect(deck.current == .welcome)
    }

    @Test func goingBackFromTheFirstSlideDoesNothing() {
        var deck = OnboardingDeck()

        deck.goBack()

        #expect(deck.current == .welcome)
    }

    @Test func advancingPastTheLastSlideDoesNothing() {
        var deck = OnboardingDeck()

        for _ in 0..<(deck.slides.count * 2) { deck.advance() }

        #expect(deck.current == .done)
        #expect(deck.isOnLastSlide)
    }

    @Test func onlyTheFinalSlideReportsBeingLast() {
        var deck = OnboardingDeck()

        for _ in 0..<(deck.slides.count - 1) {
            #expect(!deck.isOnLastSlide)
            deck.advance()
        }

        #expect(deck.isOnLastSlide)
    }

    // MARK: - Single-slide mode

    @Test func aSingleToolDeckHoldsOnlyThatToolsSlide() {
        let deck = OnboardingDeck(singleTool: .capture)

        #expect(deck.slides == [.tool(.capture)])
        #expect(deck.current == .tool(.capture))
    }

    /// Single-slide mode is the "you revoked a permission" path. It shows no
    /// dots and no Back/Next, so it must not report anywhere to navigate to.
    @Test func aSingleToolDeckHasNowhereToNavigate() {
        var deck = OnboardingDeck(singleTool: .capture)

        #expect(!deck.canGoBack)
        #expect(deck.isOnLastSlide)

        deck.advance()
        deck.goBack()

        #expect(deck.current == .tool(.capture))
    }

    @Test func aSingleToolDeckIsNotTheWizard() {
        #expect(!OnboardingDeck(singleTool: .capture).isWizard)
        #expect(OnboardingDeck().isWizard)
    }
}
