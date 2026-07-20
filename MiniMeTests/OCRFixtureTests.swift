//
//  OCRFixtureTests.swift
//  MiniMeTests
//
//  Regression corpus for OCR quality. Drop a PNG into MiniMeTests/Fixtures/ and
//  add an entry to ocr-fixtures.json listing substrings the engine must recover.
//  Every fixture is checked on each test run, so accuracy can be improved and
//  protected over time.
//

import Testing
import CoreGraphics
@testable import MiniMe

struct OCRFixtureTests {

    @Test func corpusIsNotEmpty() throws {
        let fixtures = try OCRFixtureLoader.loadAll()
        #expect(!fixtures.isEmpty)
    }

    @Test func allFixturesRecognizeExpectedText() throws {
        let engine = OCREngine()
        let fixtures = try OCRFixtureLoader.loadAll()

        for fixture in fixtures {
            let image = try #require(
                fixture.loadCGImage(),
                "Could not load fixture image \(fixture.image)"
            )
            let text = engine.recognizeText(in: image)

            for expected in fixture.mustContain {
                #expect(
                    text.contains(expected),
                    "Fixture \(fixture.image): expected to contain \"\(expected)\"\nGot:\n\(text)"
                )
            }
        }
    }
}
