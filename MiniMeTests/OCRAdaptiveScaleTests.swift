//
//  OCRAdaptiveScaleTests.swift
//  MiniMeTests
//
//  Tests for the pure scale-decision helper that drives glyph-based upscaling.
//

import Testing
import CoreGraphics
@testable import MiniMe

struct OCRAdaptiveScaleTests {

    @Test func returnsOneWhenGlyphsAlreadyLargeEnough() {
        let scale = OCRImageProcessor.adaptiveScale(
            medianGlyphHeightPx: 40,
            targetHeightPx: 32,
            maxScale: 4
        )
        #expect(scale == 1)
    }

    @Test func scalesUpProportionallyForSmallGlyphs() {
        // 16px glyphs, target 32px -> 2x.
        let scale = OCRImageProcessor.adaptiveScale(
            medianGlyphHeightPx: 16,
            targetHeightPx: 32,
            maxScale: 4
        )
        #expect(scale == 2)
    }

    @Test func capsScaleAtMaxScale() {
        // 4px glyphs would need 8x to reach 32px, but capped at 4x.
        let scale = OCRImageProcessor.adaptiveScale(
            medianGlyphHeightPx: 4,
            targetHeightPx: 32,
            maxScale: 4
        )
        #expect(scale == 4)
    }

    @Test func returnsOneForNonPositiveMedian() {
        let scale = OCRImageProcessor.adaptiveScale(
            medianGlyphHeightPx: 0,
            targetHeightPx: 32,
            maxScale: 4
        )
        #expect(scale == 1)
    }
}
