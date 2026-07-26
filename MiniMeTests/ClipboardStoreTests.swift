//
//  ClipboardStoreTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

@MainActor
struct ClipboardStoreTests {

    /// A fresh temp directory per store, so tests never touch the real container.
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func startsEmpty() {
        let store = ClipboardStore(directory: makeTempDirectory())
        #expect(store.entries.isEmpty)
    }

    @Test func addInsertsNewestFirst() {
        let store = ClipboardStore(directory: makeTempDirectory())
        store.add(ClipboardEntry(content: .text("first")))
        store.add(ClipboardEntry(content: .text("second")))

        #expect(store.entries.count == 2)
        #expect(store.entries[0].content == .text("second"))
        #expect(store.entries[1].content == .text("first"))
    }

    @Test func duplicateTextMovesExistingEntryToTop() {
        let store = ClipboardStore(directory: makeTempDirectory())
        store.add(ClipboardEntry(content: .text("alpha")))
        store.add(ClipboardEntry(content: .text("beta")))
        store.add(ClipboardEntry(content: .text("gamma")))

        store.add(ClipboardEntry(content: .text("alpha")))

        #expect(store.entries.count == 3)
        #expect(store.entries[0].content == .text("alpha"))
        #expect(store.entries[1].content == .text("gamma"))
        #expect(store.entries[2].content == .text("beta"))
    }

    @Test func duplicateRefreshesTimestamp() {
        let store = ClipboardStore(directory: makeTempDirectory())
        let old = Date(timeIntervalSince1970: 0)
        store.add(ClipboardEntry(content: .text("alpha"), timestamp: old))

        let now = Date()
        store.add(ClipboardEntry(content: .text("alpha"), timestamp: now))

        #expect(store.entries.count == 1)
        #expect(store.entries[0].timestamp == now)
    }

    @Test func duplicateSearchesWholeHistoryNotJustNewest() {
        let store = ClipboardStore(directory: makeTempDirectory())
        for index in 0..<20 {
            store.add(ClipboardEntry(content: .text("item \(index)")))
        }
        store.add(ClipboardEntry(content: .text("item 0")))

        #expect(store.entries.count == 20)
        #expect(store.entries[0].content == .text("item 0"))
    }

    @Test func identicalImagesAreNotDeduplicated() {
        let store = ClipboardStore(directory: makeTempDirectory())
        store.add(ClipboardEntry(content: .image(fileName: "a.png", pixelWidth: 2, pixelHeight: 2)))
        store.add(ClipboardEntry(content: .image(fileName: "a.png", pixelWidth: 2, pixelHeight: 2)))

        #expect(store.entries.count == 2)
    }

    @Test func exceedingLimitEvictsOldest() {
        let store = ClipboardStore(directory: makeTempDirectory(), maxEntries: 3)
        store.add(ClipboardEntry(content: .text("one")))
        store.add(ClipboardEntry(content: .text("two")))
        store.add(ClipboardEntry(content: .text("three")))
        store.add(ClipboardEntry(content: .text("four")))

        #expect(store.entries.count == 3)
        #expect(store.entries.map(\.content) == [.text("four"), .text("three"), .text("two")])
    }

    @Test func evictionDeletesBlobFiles() {
        let directory = makeTempDirectory()
        let store = ClipboardStore(directory: directory, maxEntries: 1)

        store.writeBlob(Data([0x1, 0x2]), named: "doomed.png")
        store.add(ClipboardEntry(content: .image(fileName: "doomed.png", pixelWidth: 1, pixelHeight: 1)))
        #expect(FileManager.default.fileExists(atPath: store.blobURL(named: "doomed.png").path))

        store.add(ClipboardEntry(content: .text("pushes the image out")))

        #expect(store.entries.count == 1)
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "doomed.png").path))
    }

    @Test func loweringLimitEvictsImmediately() {
        let store = ClipboardStore(directory: makeTempDirectory(), maxEntries: 10)
        for index in 0..<10 {
            store.add(ClipboardEntry(content: .text("item \(index)")))
        }

        store.maxEntries = 4

        #expect(store.entries.count == 4)
        #expect(store.entries[0].content == .text("item 9"))
    }

    @Test func deleteByIDRemovesEntryAndBlobs() {
        let store = ClipboardStore(directory: makeTempDirectory())
        store.writeBlob(Data([0x9]), named: "img.png")
        store.writeBlob(Data([0x9]), named: "img-thumb.png")

        let entry = ClipboardEntry(
            content: .image(fileName: "img.png", pixelWidth: 1, pixelHeight: 1),
            thumbnailFileName: "img-thumb.png"
        )
        store.add(entry)

        store.delete(id: entry.id)

        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "img.png").path))
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "img-thumb.png").path))
    }

    @Test func clearAllEmptiesEntriesAndBlobs() {
        let store = ClipboardStore(directory: makeTempDirectory())
        store.writeBlob(Data([0x7]), named: "one.png")
        store.add(ClipboardEntry(content: .image(fileName: "one.png", pixelWidth: 1, pixelHeight: 1)))
        store.add(ClipboardEntry(content: .text("text")))

        store.clearAll()

        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "one.png").path))
    }

    @Test func setThumbnailUpdatesEntry() {
        let store = ClipboardStore(directory: makeTempDirectory())
        let entry = ClipboardEntry(content: .files(paths: ["/tmp/a.pdf"]))
        store.add(entry)

        store.setThumbnail("a-thumb.png", forEntry: entry.id)

        #expect(store.entries[0].thumbnailFileName == "a-thumb.png")
    }

    @Test func entriesPersistAcrossStoreInstances() {
        let directory = makeTempDirectory()
        let first = ClipboardStore(directory: directory)
        first.add(ClipboardEntry(content: .text("persisted")))

        let second = ClipboardStore(directory: directory)

        #expect(second.entries.count == 1)
        #expect(second.entries[0].content == .text("persisted"))
    }

    @Test func orphanedBlobsAreSweptOnLoad() {
        let directory = makeTempDirectory()
        let first = ClipboardStore(directory: directory)
        first.add(ClipboardEntry(content: .text("keeps metadata non-empty")))
        first.writeBlob(Data([0x5]), named: "orphan.png")
        #expect(FileManager.default.fileExists(atPath: first.blobURL(named: "orphan.png").path))

        let second = ClipboardStore(directory: directory)

        #expect(!FileManager.default.fileExists(atPath: second.blobURL(named: "orphan.png").path))
        #expect(second.entries.count == 1)
    }

    @Test func referencedBlobsSurviveTheSweep() {
        let directory = makeTempDirectory()
        let first = ClipboardStore(directory: directory)
        first.writeBlob(Data([0x5]), named: "kept.png")
        first.add(ClipboardEntry(content: .image(fileName: "kept.png", pixelWidth: 1, pixelHeight: 1)))

        let second = ClipboardStore(directory: directory)

        #expect(FileManager.default.fileExists(atPath: second.blobURL(named: "kept.png").path))
    }

    @Test func corruptMetadataYieldsEmptyStoreWithoutCrashing() throws {
        let directory = makeTempDirectory()
        let metadata = directory.appendingPathComponent("clipboard.json")
        try Data("{ not valid json at all".utf8).write(to: metadata)

        let store = ClipboardStore(directory: directory)

        #expect(store.entries.isEmpty)
        // The corrupt file is preserved rather than destroyed.
        #expect(FileManager.default.fileExists(atPath: metadata.path))
    }
}
