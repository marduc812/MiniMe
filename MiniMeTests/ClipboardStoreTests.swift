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

    @Test func startsEmpty() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        #expect(store.entries.isEmpty)
    }

    @Test func addInsertsNewestFirst() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        store.add(ClipboardEntry(content: .text("first")))
        store.add(ClipboardEntry(content: .text("second")))

        #expect(store.entries.count == 2)
        #expect(store.entries[0].content == .text("second"))
        #expect(store.entries[1].content == .text("first"))
    }

    @Test func duplicateTextMovesExistingEntryToTop() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        store.add(ClipboardEntry(content: .text("alpha")))
        store.add(ClipboardEntry(content: .text("beta")))
        store.add(ClipboardEntry(content: .text("gamma")))

        store.add(ClipboardEntry(content: .text("alpha")))

        #expect(store.entries.count == 3)
        #expect(store.entries[0].content == .text("alpha"))
        #expect(store.entries[1].content == .text("gamma"))
        #expect(store.entries[2].content == .text("beta"))
    }

    @Test func duplicateRefreshesTimestamp() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        let old = Date(timeIntervalSince1970: 0)
        store.add(ClipboardEntry(content: .text("alpha"), timestamp: old))

        let now = Date()
        store.add(ClipboardEntry(content: .text("alpha"), timestamp: now))

        #expect(store.entries.count == 1)
        #expect(store.entries[0].timestamp == now)
    }

    @Test func duplicateSearchesWholeHistoryNotJustNewest() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        for index in 0..<20 {
            store.add(ClipboardEntry(content: .text("item \(index)")))
        }
        store.add(ClipboardEntry(content: .text("item 0")))

        #expect(store.entries.count == 20)
        #expect(store.entries[0].content == .text("item 0"))
    }

    @Test func selectedEntryBecomesMostRecentAcrossStoreInstances() async {
        let directory = makeTempDirectory()
        let store = ClipboardStore(directory: directory)
        await store.waitUntilLoaded()
        let selected = ClipboardEntry(content: .text("first"), timestamp: Date(timeIntervalSince1970: 100))
        let other = ClipboardEntry(content: .text("second"), timestamp: Date(timeIntervalSince1970: 200))
        let selectedAt = Date(timeIntervalSince1970: 300)
        store.add(selected)
        store.add(other)

        store.moveToTop(id: selected.id, at: selectedAt)

        #expect(store.entries.map(\.id) == [selected.id, other.id])
        #expect(store.entries[0].timestamp == selectedAt)

        await store.flush()
        let reloaded = ClipboardStore(directory: directory)
        await reloaded.waitUntilLoaded()
        #expect(reloaded.entries.map(\.id) == [selected.id, other.id])
        #expect(reloaded.entries[0].timestamp == selectedAt)
    }

    @Test func selectingImageKeepsItsBlobAndThumbnail() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        await store.writeBlob(Data([0x1]), named: "selected.png")
        await store.writeBlob(Data([0x2]), named: "selected-thumb.png")
        let selected = ClipboardEntry(
            content: .image(fileName: "selected.png", pixelWidth: 1, pixelHeight: 1),
            thumbnailFileName: "selected-thumb.png"
        )
        store.add(selected)
        store.add(ClipboardEntry(content: .text("newer")))

        store.moveToTop(id: selected.id)

        #expect(store.entries.count == 2)
        #expect(store.entries[0].id == selected.id)
        #expect(store.entries[0].thumbnailFileName == "selected-thumb.png")
        #expect(FileManager.default.fileExists(atPath: store.blobURL(named: "selected.png").path))
        #expect(FileManager.default.fileExists(atPath: store.blobURL(named: "selected-thumb.png").path))
    }

    @Test func identicalImagesAreNotDeduplicated() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        store.add(ClipboardEntry(content: .image(fileName: "a.png", pixelWidth: 2, pixelHeight: 2)))
        store.add(ClipboardEntry(content: .image(fileName: "a.png", pixelWidth: 2, pixelHeight: 2)))

        #expect(store.entries.count == 2)
    }

    @Test func exceedingLimitEvictsOldest() async {
        let store = ClipboardStore(directory: makeTempDirectory(), maxEntries: 3)
        await store.waitUntilLoaded()
        store.add(ClipboardEntry(content: .text("one")))
        store.add(ClipboardEntry(content: .text("two")))
        store.add(ClipboardEntry(content: .text("three")))
        store.add(ClipboardEntry(content: .text("four")))

        #expect(store.entries.count == 3)
        #expect(store.entries.map(\.content) == [.text("four"), .text("three"), .text("two")])
    }

    @Test func evictionDeletesBlobFiles() async {
        let directory = makeTempDirectory()
        let store = ClipboardStore(directory: directory, maxEntries: 1)
        await store.waitUntilLoaded()

        await store.writeBlob(Data([0x1, 0x2]), named: "doomed.png")
        store.add(ClipboardEntry(content: .image(fileName: "doomed.png", pixelWidth: 1, pixelHeight: 1)))
        #expect(FileManager.default.fileExists(atPath: store.blobURL(named: "doomed.png").path))

        store.add(ClipboardEntry(content: .text("pushes the image out")))
        await store.flush()

        #expect(store.entries.count == 1)
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "doomed.png").path))
    }

    @Test func loweringLimitEvictsImmediately() async {
        let store = ClipboardStore(directory: makeTempDirectory(), maxEntries: 10)
        await store.waitUntilLoaded()
        for index in 0..<10 {
            store.add(ClipboardEntry(content: .text("item \(index)")))
        }

        store.maxEntries = 4

        #expect(store.entries.count == 4)
        #expect(store.entries[0].content == .text("item 9"))
    }

    @Test func deleteByIDRemovesEntryAndBlobs() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        await store.writeBlob(Data([0x9]), named: "img.png")
        await store.writeBlob(Data([0x9]), named: "img-thumb.png")

        let entry = ClipboardEntry(
            content: .image(fileName: "img.png", pixelWidth: 1, pixelHeight: 1),
            thumbnailFileName: "img-thumb.png"
        )
        store.add(entry)

        store.delete(id: entry.id)
        await store.flush()

        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "img.png").path))
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "img-thumb.png").path))
    }

    @Test func clearAllEmptiesEntriesAndBlobs() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        await store.writeBlob(Data([0x7]), named: "one.png")
        store.add(ClipboardEntry(content: .image(fileName: "one.png", pixelWidth: 1, pixelHeight: 1)))
        store.add(ClipboardEntry(content: .text("text")))

        store.clearAll()
        await store.flush()

        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.blobURL(named: "one.png").path))
    }

    @Test func setThumbnailUpdatesEntry() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        await store.waitUntilLoaded()
        let entry = ClipboardEntry(content: .files(paths: ["/tmp/a.pdf"]))
        store.add(entry)

        store.setThumbnail("a-thumb.png", forEntry: entry.id)

        #expect(store.entries[0].thumbnailFileName == "a-thumb.png")
    }

    @Test func entriesPersistAcrossStoreInstances() async {
        let directory = makeTempDirectory()
        let first = ClipboardStore(directory: directory)
        await first.waitUntilLoaded()
        first.add(ClipboardEntry(content: .text("persisted")))

        await first.flush()
        let second = ClipboardStore(directory: directory)
        await second.waitUntilLoaded()

        #expect(second.entries.count == 1)
        #expect(second.entries[0].content == .text("persisted"))
    }

    @Test func orphanedBlobsAreSweptOnLoad() async {
        let directory = makeTempDirectory()
        let first = ClipboardStore(directory: directory)
        await first.waitUntilLoaded()
        first.add(ClipboardEntry(content: .text("keeps metadata non-empty")))
        await first.writeBlob(Data([0x5]), named: "orphan.png")
        #expect(FileManager.default.fileExists(atPath: first.blobURL(named: "orphan.png").path))

        await first.flush()
        let second = ClipboardStore(directory: directory)
        await second.waitUntilLoaded()

        #expect(!FileManager.default.fileExists(atPath: second.blobURL(named: "orphan.png").path))
        #expect(second.entries.count == 1)
    }

    @Test func referencedBlobsSurviveTheSweep() async {
        let directory = makeTempDirectory()
        let first = ClipboardStore(directory: directory)
        await first.waitUntilLoaded()
        await first.writeBlob(Data([0x5]), named: "kept.png")
        first.add(ClipboardEntry(content: .image(fileName: "kept.png", pixelWidth: 1, pixelHeight: 1)))

        await first.flush()
        let second = ClipboardStore(directory: directory)
        await second.waitUntilLoaded()

        #expect(FileManager.default.fileExists(atPath: second.blobURL(named: "kept.png").path))
    }

    @Test func corruptMetadataYieldsEmptyStoreWithoutCrashing() async throws {
        let directory = makeTempDirectory()
        let metadata = directory.appendingPathComponent("clipboard.json")
        try Data("{ not valid json at all".utf8).write(to: metadata)

        let store = ClipboardStore(directory: directory)
        await store.waitUntilLoaded()

        #expect(store.entries.isEmpty)
        // The corrupt file is preserved rather than destroyed.
        #expect(FileManager.default.fileExists(atPath: metadata.path))
    }
    @Test func mutationsDuringLoadingPreserveSavedHistory() async throws {
        let directory = makeTempDirectory()
        let old = ClipboardEntry(content: .text("saved"))
        try JSONEncoder().encode([old]).write(to: directory.appendingPathComponent("clipboard.json"))
        let queue = DispatchQueue(label: "clipboard-store-load-test")
        queue.suspend()
        let store = ClipboardStore(directory: directory, ioQueue: queue)
        let new = ClipboardEntry(content: .text("copied during loading"))
        store.add(new)
        queue.resume()
        await store.flush()
        #expect(store.entries.map(\.id) == [new.id, old.id])
    }

    @Test func clearDuringLoadingDoesNotResurrectSavedEntries() async throws {
        let directory = makeTempDirectory()
        try JSONEncoder().encode([ClipboardEntry(content: .text("saved"))])
            .write(to: directory.appendingPathComponent("clipboard.json"))
        let queue = DispatchQueue(label: "clipboard-store-clear-test")
        queue.suspend()
        let store = ClipboardStore(directory: directory, ioQueue: queue)
        store.clearAll()
        queue.resume()
        await store.flush()
        #expect(store.entries.isEmpty)
        let persisted = try JSONDecoder().decode([ClipboardEntry].self,
            from: Data(contentsOf: directory.appendingPathComponent("clipboard.json")))
        #expect(persisted.isEmpty)
    }

    @Test func blockedDiskDoesNotBlockMutationsAndLatestSnapshotWins() async throws {
        let directory = makeTempDirectory()
        let queue = DispatchQueue(label: "clipboard-store-save-test")
        let store = ClipboardStore(directory: directory, ioQueue: queue)
        await store.waitUntilLoaded()
        queue.suspend()
        store.add(ClipboardEntry(content: .text("first")))
        store.add(ClipboardEntry(content: .text("second")))
        store.clearAll()
        store.add(ClipboardEntry(content: .text("last")))
        #expect(store.entries.map(\.content) == [.text("last")])
        queue.resume()
        await store.flush()
        let persisted = try JSONDecoder().decode([ClipboardEntry].self,
            from: Data(contentsOf: directory.appendingPathComponent("clipboard.json")))
        #expect(persisted.map(\.content) == [.text("last")])
    }

}
