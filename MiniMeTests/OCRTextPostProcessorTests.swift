//
//  OCRTextPostProcessorTests.swift
//  MiniMeTests
//
//  Unit tests for the pure text-cleanup pass applied after recognition.
//

import Testing
@testable import MiniMe

struct OCRTextPostProcessorTests {

    @Test func dehyphenatesLineWrappedWord() {
        let input = "inter-\nnational"
        #expect(OCRTextPostProcessor.clean(input) == "international")
    }

    @Test func keepsRealHyphenAcrossLinesWhenNextWordIsCapitalized() {
        // A capitalized continuation is likely a genuine hyphenated phrase, not
        // a soft line-wrap, so keep the newline and the hyphen.
        let input = "Anglo-\nSaxon"
        #expect(OCRTextPostProcessor.clean(input) == "Anglo-\nSaxon")
    }

    @Test func doesNotJoinHyphenWhenNextLineStartsWithNonLetter() {
        let input = "budget-\n2026 figures"
        #expect(OCRTextPostProcessor.clean(input) == "budget-\n2026 figures")
    }

    @Test func stripsTrailingWhitespacePerLine() {
        let input = "hello   \nworld\t"
        #expect(OCRTextPostProcessor.clean(input) == "hello\nworld")
    }

    @Test func collapsesThreeOrMoreBlankLinesToOne() {
        let input = "a\n\n\n\nb"
        #expect(OCRTextPostProcessor.clean(input) == "a\n\nb")
    }

    @Test func trimsLeadingAndTrailingWhitespace() {
        let input = "\n\n  hello world  \n\n"
        #expect(OCRTextPostProcessor.clean(input) == "hello world")
    }

    @Test func leavesCleanTextUnchanged() {
        let input = "The quick brown fox\njumps over the lazy dog"
        #expect(OCRTextPostProcessor.clean(input) == input)
    }

    @Test func returnsEmptyForEmptyInput() {
        #expect(OCRTextPostProcessor.clean("") == "")
    }
}
