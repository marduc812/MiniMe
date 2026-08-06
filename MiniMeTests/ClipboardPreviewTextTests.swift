//
//  ClipboardPreviewTextTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct ClipboardPreviewTextTests {

    // MARK: - Short clippings pass through

    @Test func shortClippingIsPreviewedWhole() {
        let preview = ClipboardPreviewText.preview(for: "hello")
        #expect(preview.text == "hello")
        #expect(preview.omittedCharacters == 0)
        #expect(preview.isTruncated == false)
    }

    @Test func emptyClippingIsPreviewedWhole() {
        let preview = ClipboardPreviewText.preview(for: "")
        #expect(preview.text.isEmpty)
        #expect(preview.isTruncated == false)
    }

    @Test func clippingExactlyAtTheCapIsPreviewedWhole() {
        let string = String(repeating: "a", count: ClipboardPreviewText.maxLength)
        let preview = ClipboardPreviewText.preview(for: string)
        #expect(preview.text == string)
        #expect(preview.omittedCharacters == 0)
        #expect(preview.isTruncated == false)
    }

    // MARK: - Long clippings are cut

    @Test func clippingOneCharacterPastTheCapIsCut() {
        let string = String(repeating: "a", count: ClipboardPreviewText.maxLength + 1)
        let preview = ClipboardPreviewText.preview(for: string)
        #expect(preview.text.count == ClipboardPreviewText.maxLength)
        #expect(preview.omittedCharacters == 1)
        #expect(preview.isTruncated)
    }

    @Test func cutPreviewKeepsTheStartOfTheClipping() {
        let string = "FIRST" + String(repeating: "a", count: ClipboardPreviewText.maxLength)
        let preview = ClipboardPreviewText.preview(for: string)
        #expect(preview.text.hasPrefix("FIRST"))
    }

    @Test func omittedCountIsTheRemainderOfTheClipping() {
        let overflow = 1_234
        let string = String(repeating: "a", count: ClipboardPreviewText.maxLength + overflow)
        #expect(ClipboardPreviewText.preview(for: string).omittedCharacters == overflow)
    }

    /// The cut is by character, so a multi-scalar grapheme at the boundary is
    /// never split into a broken glyph.
    @Test func cutDoesNotSplitGraphemeClusters() {
        let flag = "🇬🇷"
        let string = String(repeating: flag, count: ClipboardPreviewText.maxLength + 100)
        let preview = ClipboardPreviewText.preview(for: string)
        #expect(preview.text.count == ClipboardPreviewText.maxLength)
        #expect(preview.text.allSatisfy { String($0) == flag })
    }

    // MARK: - Regression

    /// The clipping that beachballed the picker: a 56k-character terminal dump
    /// whose box-drawing glyphs force CoreText through font fallback. Measuring
    /// it whole took 3.3 s on the main thread, so the preview must never see
    /// more than the cap regardless of how large the clipping is.
    @Test func hugeGlyphHeavyClippingIsCutToTheCap() {
        let line = "⏺ ── │ ⎿ ■ █ some terminal output that goes on and on\n"
        let dump = String(repeating: line, count: 1_100)
        #expect(dump.count > 50_000, "fixture should reproduce the reported size")

        let preview = ClipboardPreviewText.preview(for: dump)
        #expect(preview.text.count == ClipboardPreviewText.maxLength)
        #expect(preview.omittedCharacters == dump.count - ClipboardPreviewText.maxLength)
    }

    /// A cap this high defeats the point: the measured cost of laying out the
    /// reported clipping was ~73 ms at 4k characters and ~220 ms at 8k.
    @Test func capIsSmallEnoughToLayOutWithinAFrameBudget() {
        #expect(ClipboardPreviewText.maxLength <= 4_000)
    }
}
