//
//  ClipboardHighlightTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct ClipboardHighlightTests {

    private func entries(_ count: Int) -> [ClipboardEntry] {
        (0..<count).map { ClipboardEntry(content: .text("entry \($0)")) }
    }

    private let restingPointer = CGPoint(x: 400, y: 300)

    // MARK: - Which row is active

    @Test func theTopRowIsActiveWhenNothingIsSelectedOrHovered() {
        let visible = entries(3)
        let highlight = ClipboardHighlight()

        #expect(highlight.activeEntry(in: visible)?.id == visible[0].id)
    }

    @Test func hoverWinsOverTheKeyboardSelection() {
        let visible = entries(3)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)

        highlight.pointerEntered(visible[2].id, at: restingPointer)

        #expect(highlight.activeEntry(in: visible)?.id == visible[2].id)
    }

    @Test func aSelectionThatIsNoLongerVisibleFallsBackToTheTopRow() {
        let visible = entries(3)
        let highlight = ClipboardHighlight(selectedID: UUID())

        #expect(highlight.activeEntry(in: visible)?.id == visible[0].id)
    }

    // MARK: - Keyboard takes over from the pointer

    @Test func keyboardSelectionDropsAStaleHover() {
        let visible = entries(5)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)
        highlight.pointerEntered(visible[1].id, at: restingPointer)

        highlight.keyboardSelected(visible[2].id, at: restingPointer)

        #expect(highlight.activeEntry(in: visible)?.id == visible[2].id)
    }

    /// The bug: scrolling the list slides rows under a cursor that never moved,
    /// and AppKit reports that as a hover. Acting on it drags the highlight back
    /// to whatever the pointer happens to be resting on.
    @Test func aRowSlidingUnderARestingPointerDoesNotStealTheHighlight() {
        let visible = entries(20)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)
        highlight.pointerEntered(visible[1].id, at: restingPointer)

        highlight.keyboardSelected(visible[3].id, at: restingPointer)
        // The scroll that follows brings a different row under the same cursor.
        highlight.pointerEntered(visible[8].id, at: restingPointer)

        #expect(highlight.activeEntry(in: visible)?.id == visible[3].id)
    }

    @Test func successiveArrowKeysKeepIgnoringTheRestingPointer() {
        let visible = entries(20)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)

        for index in 1...5 {
            highlight.keyboardSelected(visible[index].id, at: restingPointer)
            highlight.pointerEntered(visible[10].id, at: restingPointer)
        }

        #expect(highlight.activeEntry(in: visible)?.id == visible[5].id)
    }

    @Test func movingThePointerHandsTheHighlightBack() {
        let visible = entries(20)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)
        highlight.keyboardSelected(visible[3].id, at: restingPointer)

        highlight.pointerEntered(visible[8].id, at: CGPoint(x: 401, y: 300))

        #expect(highlight.activeEntry(in: visible)?.id == visible[8].id)
    }

    @Test func aHoverArrivingBeforeAnyKeyboardUseIsHonoured() {
        let visible = entries(3)
        var highlight = ClipboardHighlight()

        highlight.pointerEntered(visible[1].id, at: restingPointer)

        #expect(highlight.activeEntry(in: visible)?.id == visible[1].id)
    }

    // MARK: - Resetting

    @Test func resetClearsTheHoverAndLetsThePointerBackIn() {
        let visible = entries(5)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)
        highlight.keyboardSelected(visible[3].id, at: restingPointer)

        highlight.reset(to: visible[0].id)

        #expect(highlight.selectedID == visible[0].id)
        #expect(highlight.activeEntry(in: visible)?.id == visible[0].id)

        // A pointer that has not moved is live again: the list changed under it.
        highlight.pointerEntered(visible[2].id, at: restingPointer)
        #expect(highlight.activeEntry(in: visible)?.id == visible[2].id)
    }

    @Test func forgettingAHoveredRowFallsBackToTheSelection() {
        let visible = entries(5)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)
        highlight.pointerEntered(visible[2].id, at: restingPointer)

        highlight.forgetHover(of: visible[2].id)

        #expect(highlight.activeEntry(in: visible)?.id == visible[0].id)
    }

    @Test func forgettingAnotherRowLeavesTheHoverAlone() {
        let visible = entries(5)
        var highlight = ClipboardHighlight(selectedID: visible[0].id)
        highlight.pointerEntered(visible[2].id, at: restingPointer)

        highlight.forgetHover(of: visible[4].id)

        #expect(highlight.activeEntry(in: visible)?.id == visible[2].id)
    }
}
