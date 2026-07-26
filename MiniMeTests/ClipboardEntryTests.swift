//
//  ClipboardEntryTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct ClipboardEntryTests {

    // MARK: - Title generation

    @Test func textTitleUsesFirstNonEmptyLine() {
        let entry = ClipboardEntry(content: .text("\n\n  git push origin main  \nsecond line"))
        #expect(entry.title == "git push origin main")
    }

    @Test func textTitleTruncatesAtFiftyCharacters() {
        let long = String(repeating: "a", count: 80)
        let entry = ClipboardEntry(content: .text(long))
        #expect(entry.title == String(repeating: "a", count: 47) + "...")
        #expect(entry.title.count == 50)
    }

    @Test func textTitleKeepsExactlyFiftyCharacters() {
        let exact = String(repeating: "b", count: 50)
        let entry = ClipboardEntry(content: .text(exact))
        #expect(entry.title == exact)
    }

    @Test func blankTextTitleIsUntitled() {
        let entry = ClipboardEntry(content: .text("   \n\t  "))
        #expect(entry.title == "Untitled")
    }

    @Test func imageTitleShowsDimensions() {
        let entry = ClipboardEntry(content: .image(fileName: "a.png", pixelWidth: 1290, pixelHeight: 800))
        #expect(entry.title == "Image 1290×800")
    }

    @Test func singleFileTitleIsFileName() {
        let entry = ClipboardEntry(content: .files(paths: ["/Users/me/Music/interview-take-3.m4a"]))
        #expect(entry.title == "interview-take-3.m4a")
    }

    @Test func multipleFilesTitleIsCount() {
        let entry = ClipboardEntry(content: .files(paths: ["/a/one.txt", "/a/two.txt", "/a/three.txt"]))
        #expect(entry.title == "3 files")
    }

    // MARK: - Search matching

    @Test func emptyQueryMatchesEverything() {
        let entry = ClipboardEntry(content: .text("hello"))
        #expect(entry.matches(query: ""))
        #expect(entry.matches(query: "   "))
    }

    @Test func matchesOnFullTextNotJustTitle() {
        let entry = ClipboardEntry(content: .text("first line\nburied treasure"))
        #expect(entry.title == "first line")
        #expect(entry.matches(query: "treasure"))
    }

    @Test func matchingIsCaseInsensitive() {
        let entry = ClipboardEntry(content: .text("Hello World"))
        #expect(entry.matches(query: "hello"))
        #expect(entry.matches(query: "WORLD"))
    }

    @Test func fileEntryMatchesOnFileName() {
        let entry = ClipboardEntry(content: .files(paths: ["/deep/path/report.pdf", "/deep/path/notes.txt"]))
        #expect(entry.matches(query: "notes"))
        #expect(entry.matches(query: "REPORT"))
    }

    @Test func imageEntryMatchesTitleOnly() {
        let entry = ClipboardEntry(content: .image(fileName: "secret.png", pixelWidth: 10, pixelHeight: 20))
        #expect(entry.matches(query: "Image"))
        #expect(entry.matches(query: "10×20"))
        #expect(!entry.matches(query: "secret"))
    }

    // MARK: - Codability

    @Test func textEntryRoundTrips() throws {
        let original = ClipboardEntry(
            content: .text("round trip"),
            sourceAppName: "Safari",
            sourceAppBundleID: "com.apple.Safari"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardEntry.self, from: data)
        #expect(decoded == original)
    }

    @Test func imageEntryRoundTrips() throws {
        let original = ClipboardEntry(
            content: .image(fileName: "x.png", pixelWidth: 4, pixelHeight: 5),
            thumbnailFileName: "x-thumb.png"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardEntry.self, from: data)
        #expect(decoded == original)
        #expect(decoded.thumbnailFileName == "x-thumb.png")
    }

    @Test func filesEntryRoundTrips() throws {
        let original = ClipboardEntry(content: .files(paths: ["/a/b.txt", "/c/d.txt"]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardEntry.self, from: data)
        #expect(decoded == original)
    }

    @Test func isImageFlagIsOnlyTrueForImages() {
        #expect(ClipboardContent.image(fileName: "a", pixelWidth: 1, pixelHeight: 1).isImage)
        #expect(!ClipboardContent.text("a").isImage)
        #expect(!ClipboardContent.files(paths: ["/a"]).isImage)
    }
}
