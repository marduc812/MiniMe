//
//  OCREngineTests.swift
//  MiniMeTests
//
//  Integration tests for the Vision-backed OCR engine using deterministic
//  rendered-text images.
//

import Testing
import CoreGraphics
@testable import MiniMe

struct OCREngineTests {

    private let engine = OCREngine()

    @Test func recognizesSingleWord() {
        let image = OCRTestSupport.renderText("Hello")

        let text = engine.recognizeText(in: image)

        #expect(text.contains("Hello"))
    }

    @Test func recognizesMultipleWordsOnOneLine() {
        let image = OCRTestSupport.renderText("Open Source")

        let text = engine.recognizeText(in: image)

        #expect(text.contains("Open"))
        #expect(text.contains("Source"))
    }

    @Test func lineAwareModePreservesTopToBottomOrder() {
        let image = OCRTestSupport.renderLines(["First", "Second", "Third"])

        var options = OCROptions.default
        options.lineAware = true
        let text = engine.recognizeText(in: image, options: options)

        let first = try! #require(text.range(of: "First"))
        let second = try! #require(text.range(of: "Second"))
        let third = try! #require(text.range(of: "Third"))
        #expect(first.lowerBound < second.lowerBound)
        #expect(second.lowerBound < third.lowerBound)
    }

    @Test func recognizesSmallText() {
        // A tight crop of small text is the case the raw pipeline used to fail on;
        // the engine upscales before recognition.
        let image = OCRTestSupport.renderText("Kimeno", fontSize: 11)

        let text = engine.recognizeText(in: image)

        #expect(text.contains("Kimeno"))
    }

    @Test func returnsEmptyStringForBlankImage() {
        let image = OCRTestSupport.blankImage(width: 200, height: 100)

        let text = engine.recognizeText(in: image)

        #expect(text.isEmpty)
    }
}
