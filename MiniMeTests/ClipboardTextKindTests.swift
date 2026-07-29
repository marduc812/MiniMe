//
//  ClipboardTextKindTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct ClipboardTextKindTests {

    // MARK: - Links

    @Test func detectsHTTPSLink() {
        #expect(ClipboardTextKind.detect(in: "https://example.com/path?q=1")
            == .link(URL(string: "https://example.com/path?q=1")!))
    }

    @Test func detectsLinkIgnoringSurroundingWhitespace() {
        #expect(ClipboardTextKind.detect(in: "  https://example.com\n") == .link(URL(string: "https://example.com")!))
    }

    @Test func detectsSchemelessLinkWithBrowsableURL() {
        guard case .link(let url) = ClipboardTextKind.detect(in: "www.apple.com") else {
            Issue.record("expected a link")
            return
        }
        #expect(url.scheme == "http")
    }

    @Test func textAroundALinkIsPlain() {
        #expect(ClipboardTextKind.detect(in: "Check out https://example.com now") == .plain)
    }

    // MARK: - Email

    @Test func detectsEmailAsMailtoLink() {
        #expect(ClipboardTextKind.detect(in: "someone@example.com")
            == .email(URL(string: "mailto:someone@example.com")!))
    }

    @Test func textAroundAnEmailIsPlain() {
        #expect(ClipboardTextKind.detect(in: "Contact: someone@example.com") == .plain)
    }

    // MARK: - JSON

    @Test func detectsJSONObject() {
        #expect(ClipboardTextKind.detect(in: #"{"name": "kimeno", "stars": 3}"#) == .json)
    }

    @Test func detectsJSONArray() {
        #expect(ClipboardTextKind.detect(in: "[1, 2, 3]") == .json)
    }

    @Test func detectsPrettyPrintedJSON() {
        #expect(ClipboardTextKind.detect(in: "{\n  \"a\": [true, null]\n}") == .json)
    }

    @Test func malformedJSONIsPlain() {
        #expect(ClipboardTextKind.detect(in: #"{"name": "kimeno""#) == .plain)
    }

    @Test func bareJSONScalarIsPlain() {
        #expect(ClipboardTextKind.detect(in: "123") == .plain)
        #expect(ClipboardTextKind.detect(in: #""just a string""#) == .plain)
    }

    // MARK: - UUID

    @Test func detectsUppercaseUUID() {
        #expect(ClipboardTextKind.detect(in: "550E8400-E29B-41D4-A716-446655440000") == .uuid)
    }

    @Test func detectsLowercaseUUID() {
        #expect(ClipboardTextKind.detect(in: "550e8400-e29b-41d4-a716-446655440000") == .uuid)
    }

    @Test func truncatedUUIDIsNotAUUID() {
        #expect(ClipboardTextKind.detect(in: "550e8400-e29b-41d4-a716") != .uuid)
    }

    // MARK: - Hex

    @Test func detectsHexColors() {
        #expect(ClipboardTextKind.detect(in: "#FF8800") == .hex)
        #expect(ClipboardTextKind.detect(in: "#fff") == .hex)
        #expect(ClipboardTextKind.detect(in: "#ff8800aa") == .hex)
    }

    @Test func detectsPrefixedHexNumber() {
        #expect(ClipboardTextKind.detect(in: "0xDEADBEEF") == .hex)
    }

    @Test func detectsBareHexDigest() {
        #expect(ClipboardTextKind.detect(in: "e3b0c44298fc1c149afbf4c8996fb924") == .hex)
    }

    @Test func decimalDigitsAreNotHex() {
        #expect(ClipboardTextKind.detect(in: "12345678") == .plain)
    }

    @Test func shortHexRunIsPlain() {
        // "cafe" and friends are words far more often than they are hex.
        #expect(ClipboardTextKind.detect(in: "cafe") == .plain)
    }

    // MARK: - Dates

    @Test func detectsISODate() {
        #expect(ClipboardTextKind.detect(in: "2026-07-29") == .date)
    }

    @Test func detectsISOTimestamp() {
        #expect(ClipboardTextKind.detect(in: "2026-07-29T10:15:30Z") == .date)
    }

    @Test func detectsWrittenDate() {
        #expect(ClipboardTextKind.detect(in: "July 29, 2026") == .date)
    }

    @Test func bareYearIsPlain() {
        #expect(ClipboardTextKind.detect(in: "2026") == .plain)
    }

    @Test func sentenceMentioningADateIsPlain() {
        #expect(ClipboardTextKind.detect(in: "ship it on July 29, 2026 at the latest") == .plain)
    }

    // MARK: - Plain

    @Test func ordinaryTextIsPlain() {
        #expect(ClipboardTextKind.detect(in: "git push origin main") == .plain)
    }

    @Test func emptyTextIsPlain() {
        #expect(ClipboardTextKind.detect(in: "   \n ") == .plain)
    }

    @Test func payloadPastTheScanCapIsPlainRatherThanReparsedPerRow() {
        let json = "[" + Array(repeating: "\"x\"", count: 1_000).joined(separator: ",") + "]"
        #expect(json.count > 2_048)
        #expect(ClipboardTextKind.detect(in: json) == .plain)
    }

    @Test func payloadUnderTheScanCapIsStillClassified() {
        let json = "[" + Array(repeating: "\"x\"", count: 100).joined(separator: ",") + "]"
        #expect(json.count < 2_048)
        #expect(ClipboardTextKind.detect(in: json) == .json)
    }

    @Test func longProseIsPlainWithoutScanning() {
        let prose = String(repeating: "lorem ipsum dolor sit amet ", count: 500)
        #expect(ClipboardTextKind.detect(in: prose) == .plain)
    }

    // MARK: - Symbols

    @Test func eachKindHasItsOwnSymbol() {
        let symbols = [
            ClipboardTextKind.plain,
            .link(URL(string: "https://example.com")!),
            .email(URL(string: "mailto:a@b.com")!),
            .json,
            .date,
            .hex,
            .uuid,
        ].map(\.symbolName)

        #expect(Set(symbols).count == symbols.count)
    }

    @Test func onlyLinksAndEmailsAreOpenable() {
        #expect(ClipboardTextKind.link(URL(string: "https://example.com")!).url != nil)
        #expect(ClipboardTextKind.email(URL(string: "mailto:a@b.com")!).url != nil)
        #expect(ClipboardTextKind.json.url == nil)
        #expect(ClipboardTextKind.plain.url == nil)
    }

    // MARK: - Entry integration

    @Test func textEntryExposesItsKind() {
        let entry = ClipboardEntry(content: .text("https://example.com"))
        #expect(entry.textKind == .link(URL(string: "https://example.com")!))
    }

    @Test func nonTextEntriesArePlain() {
        let image = ClipboardEntry(content: .image(fileName: "a.png", pixelWidth: 1, pixelHeight: 1))
        let files = ClipboardEntry(content: .files(paths: ["/a/b.txt"]))
        #expect(image.textKind == .plain)
        #expect(files.textKind == .plain)
    }
}
