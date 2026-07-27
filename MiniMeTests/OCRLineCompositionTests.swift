//
//  OCRLineCompositionTests.swift
//  MiniMeTests
//
//  Pure unit tests for line grouping and joining of recognized text items,
//  independent of Vision. Items are in pixel space with a bottom-left origin
//  (larger midY = higher on screen), matching what OCREngine feeds in.
//

import Testing
import CoreGraphics
@testable import MiniMe

struct OCRLineCompositionTests {

    private func item(
        _ text: String,
        minX: CGFloat,
        maxX: CGFloat,
        midY: CGFloat,
        height: CGFloat = 20
    ) -> OCREngine.TextItem {
        OCREngine.TextItem(text: text, minX: minX, maxX: maxX, midY: midY, height: height)
    }

    // MARK: - Line grouping

    @Test func ordersLinesTopToBottomRegardlessOfInputOrder() {
        // Bottom line delivered first; output must still read top to bottom.
        let items = [
            item("bottom", minX: 0, maxX: 80, midY: 10),
            item("top", minX: 0, maxX: 50, midY: 100),
        ]

        let text = OCREngine.composeLineAwareText(from: items)

        #expect(text == "top\nbottom")
    }

    @Test func groupsMixedHeightItemsOnSameBaseline() {
        // A small word followed by a large word sharing a baseline (e.g. mixed
        // font sizes in a heading). Small box: y 90-105, large box: y 90-120.
        // Grouping anchored to the small item's height alone would split them.
        let items = [
            item("small", minX: 0, maxX: 60, midY: 97.5, height: 15),
            item("BIG", minX: 70, maxX: 130, midY: 105, height: 30),
        ]

        let text = OCREngine.composeLineAwareText(from: items)

        #expect(text == "small BIG")
    }

    @Test func sortsItemsLeftToRightWithinLine() {
        let items = [
            item("right", minX: 60, maxX: 120, midY: 50),
            item("left", minX: 0, maxX: 50, midY: 50),
        ]

        let text = OCREngine.composeLineAwareText(from: items)

        #expect(text == "left right")
    }

    @Test func keepsAdjacentLinesSeparate() {
        // Two normally spaced lines (line pitch a bit above line height).
        let items = [
            item("first", minX: 0, maxX: 60, midY: 100),
            item("second", minX: 0, maxX: 70, midY: 76),
        ]

        let text = OCREngine.composeLineAwareText(from: items)

        #expect(text == "first\nsecond")
    }

    // MARK: - Gap-aware joining

    @Test func joinsDistantItemsWithTab() {
        // Vision usually merges words of a sentence into one observation, so two
        // observations far apart on a line are a real gap (columns, label/value).
        let items = [
            item("Name:", minX: 0, maxX: 100, midY: 50),
            item("John", minX: 200, maxX: 260, midY: 50),
        ]

        let text = OCREngine.composeLineAwareText(from: items)

        #expect(text == "Name:\tJohn")
    }

    @Test func joinsNearbyItemsWithSpace() {
        let items = [
            item("Hello", minX: 0, maxX: 100, midY: 50),
            item("world", minX: 108, maxX: 180, midY: 50),
        ]

        let text = OCREngine.composeLineAwareText(from: items)

        #expect(text == "Hello world")
    }

    // MARK: - Second-pass decision

    @Test func skipsSecondPassWhenNoUpscaleRequested() {
        let run = OCREngine.shouldRunSecondPass(
            requestedScale: 1,
            firstPassConfidence: 0.2,
            options: .default
        )

        #expect(!run)
    }

    @Test func skipsSecondPassWhenNearTargetAndConfident() {
        // Typical clean Retina capture: glyphs just under target, first pass
        // already near-perfect. Re-running recognition would only cost time.
        let run = OCREngine.shouldRunSecondPass(
            requestedScale: 1.3,
            firstPassConfidence: 0.99,
            options: .default
        )

        #expect(!run)
    }

    @Test func runsSecondPassWhenNearTargetButUnconfident() {
        let run = OCREngine.shouldRunSecondPass(
            requestedScale: 1.3,
            firstPassConfidence: 0.6,
            options: .default
        )

        #expect(run)
    }

    @Test func runsSecondPassForSmallGlyphsEvenWhenConfident() {
        // Tiny text can produce confident-but-wrong partial reads; a large
        // requested upscale always earns a second look.
        let run = OCREngine.shouldRunSecondPass(
            requestedScale: 3,
            firstPassConfidence: 0.99,
            options: .default
        )

        #expect(run)
    }

    @Test func runsSecondPassOnStripEvenWhenNearTargetAndConfident() {
        // Vision's detector can silently drop edge characters on thin, wide
        // strips while still reporting 1.0 confidence, so the near-target/
        // confident skip must not apply once strip padding fired.
        let run = OCREngine.shouldRunSecondPass(
            requestedScale: 1.3,
            firstPassConfidence: 0.99,
            options: .default,
            isStripPadded: true
        )

        #expect(run)
    }
}
