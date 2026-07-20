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
}
