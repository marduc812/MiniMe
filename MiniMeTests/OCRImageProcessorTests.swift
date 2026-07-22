//
//  OCRImageProcessorTests.swift
//  MiniMeTests
//

import Testing
import CoreGraphics
@testable import MiniMe

struct OCRImageProcessorTests {

    @Test func scalesImageUpToMinimumHeight() {
        let image = OCRTestSupport.blankImage(width: 100, height: 50)

        let result = OCRImageProcessor.upscaled(image, toMinimumHeight: 100, maxScale: 4)

        #expect(result.height == 100)
        #expect(result.width == 200) // aspect ratio preserved (2x)
    }

    @Test func leavesImageUnchangedWhenAlreadyTallEnough() {
        let image = OCRTestSupport.blankImage(width: 300, height: 200)

        let result = OCRImageProcessor.upscaled(image, toMinimumHeight: 100, maxScale: 4)

        // Returns the same image untouched when no upscaling is needed.
        #expect(result === image)
    }

    @Test func capsUpscalingAtMaxScale() {
        let image = OCRTestSupport.blankImage(width: 10, height: 10)

        // Would need 10x to reach 100px tall, but maxScale caps it at 4x.
        let result = OCRImageProcessor.upscaled(image, toMinimumHeight: 100, maxScale: 4)

        #expect(result.height == 40)
        #expect(result.width == 40)
    }

    @Test func preservesAspectRatioForWideImages() {
        let image = OCRTestSupport.blankImage(width: 400, height: 40)

        let result = OCRImageProcessor.upscaled(image, toMinimumHeight: 80, maxScale: 4)

        #expect(result.height == 80)
        #expect(result.width == 800)
    }

    @Test func stripPaddingAppliesOnlyToExtremeAspectRatios() {
        // A 37:1 code-line strip gets padded; a normal paragraph does not.
        #expect(OCRImageProcessor.stripPadding(width: 1239, height: 33, aspectThreshold: 15, padding: 12) == 12)
        #expect(OCRImageProcessor.stripPadding(width: 800, height: 200, aspectThreshold: 15, padding: 12) == 0)
    }

    @Test func stripPaddingGuardsAgainstDegenerateSizes() {
        #expect(OCRImageProcessor.stripPadding(width: 1000, height: 0, aspectThreshold: 15, padding: 12) == 0)
        #expect(OCRImageProcessor.stripPadding(width: 0, height: 30, aspectThreshold: 15, padding: 12) == 0)
    }

    @Test func paddedVerticallyExtendsHeightOnBothSides() {
        let image = OCRTestSupport.blankImage(width: 600, height: 30)

        let result = OCRImageProcessor.paddedVertically(image, by: 12)

        #expect(result.width == 600)
        #expect(result.height == 54)
    }

    @Test func paddedVerticallyWithZeroPaddingReturnsSameImage() {
        let image = OCRTestSupport.blankImage(width: 600, height: 30)

        let result = OCRImageProcessor.paddedVertically(image, by: 0)

        #expect(result === image)
    }
}
