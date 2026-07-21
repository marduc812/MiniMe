//
//  OCRLanguageConfigTests.swift
//  MiniMeTests
//
//  Tests that the stored language setting maps to the right Vision configuration.
//

import Testing
@testable import MiniMe

struct OCRLanguageConfigTests {

    @Test func automaticSettingEnablesDetection() {
        let config = OCROptions.languageConfiguration(for: "automatic")
        #expect(config.automatic == true)
    }

    @Test func emptySettingEnablesDetection() {
        let config = OCROptions.languageConfiguration(for: "")
        #expect(config.automatic == true)
    }

    @Test func specificLanguageConstrainsRecognition() {
        let config = OCROptions.languageConfiguration(for: "de-DE")
        #expect(config.automatic == false)
        #expect(config.languages == ["de-DE"])
    }
}
