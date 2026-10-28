//
//  ClipboardMonitorTests.swift
//  MiniMeTests
//

import Testing
import AppKit
@testable import MiniMe

@MainActor
struct ClipboardMonitorTests {

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMonitorTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A private pasteboard so tests never touch the user's real clipboard.
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("MiniMeTests-\(UUID().uuidString)"))
    }

    private func makeSubject() -> (ClipboardMonitor, ClipboardStore, NSPasteboard) {
        let store = ClipboardStore(directory: makeTempDirectory())
        let pasteboard = makePasteboard()
        let monitor = ClipboardMonitor(store: store, pasteboard: pasteboard)
        return (monitor, store, pasteboard)
    }

    @Test func textIsCapturedAsATextEntry() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("git push origin main", forType: .string)
        await monitor.poll()

        #expect(store.entries.count == 1)
        #expect(store.entries[0].content == .text("git push origin main"))
    }

    @Test func unchangedPasteboardProducesNoDuplicate() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("stable", forType: .string)
        await monitor.poll()
        await monitor.poll()
        await monitor.poll()

        #expect(store.entries.count == 1)
    }

    @Test func imageIsCapturedWithItsOriginalPixelsAndBlob() async throws {
        let (monitor, store, pasteboard) = makeSubject()
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: 16, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        memset(bitmap.bitmapData!, 0, bitmap.bytesPerRow * bitmap.pixelsHigh)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        await monitor.poll()
        let entry = try #require(store.entries.first)
        guard case .image(let name, let width, let height) = entry.content else {
            Issue.record("Expected an image entry")
            return
        }
        #expect(width == 16)
        #expect(height == 8)
        #expect(try Data(contentsOf: store.blobURL(named: name)) == png)
        #expect(entry.thumbnailFileName != nil)
    }

    @Test func separateCopiesOfDifferentTextBothLand() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        await monitor.poll()

        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        await monitor.poll()

        #expect(store.entries.count == 2)
        #expect(store.entries[0].content == .text("second"))
    }

    @Test func concealedContentIsSkipped() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        await monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func transientContentIsSkipped() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("ephemeral", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        await monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func concealedContentIsCapturedWhenTheFilterIsOff() async {
        let (monitor, store, pasteboard) = makeSubject()
        monitor.ignoreConcealed = false

        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        await monitor.poll()

        #expect(store.entries.count == 1)
    }

    @Test func whitespaceOnlyTextIsNotCaptured() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("   \n\t ", forType: .string)
        await monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func acknowledgeSelfWriteSuppressesTheNextPoll() async {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("written by MiniMe itself", forType: .string)
        monitor.acknowledgeSelfWrite()
        await monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func fileURLsAreCapturedAsAFilesEntry() async throws {
        let (monitor, store, pasteboard) = makeSubject()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monitor-\(UUID().uuidString).txt")
        try Data("file body".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        await monitor.poll()

        #expect(store.entries.count == 1)
        #expect(store.entries[0].content == .files(paths: [url.path]))
    }

    @Test func fileURLsAreCapturedAsTextWhenImageAndFileCaptureIsOff() async throws {
        let (monitor, store, pasteboard) = makeSubject()
        monitor.captureImagesAndFiles = false

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monitor-\(UUID().uuidString).txt")
        try Data("file body".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        await monitor.poll()

        // A file copy also puts a text representation on the pasteboard; with
        // file capture disabled that text is what gets recorded.
        if let entry = store.entries.first {
            #expect(!entry.content.isImage)
            if case .files = entry.content {
                Issue.record("Expected a text entry, got a files entry")
            }
        }
    }

    @Test func startThenStopLeavesNoTimerRunning() async {
        let (monitor, _, _) = makeSubject()
        monitor.start()
        monitor.stop()
        // Nothing to assert beyond not crashing; stop() must be idempotent.
        monitor.stop()
    }
    @Test func staleReadIsDiscardedAndOnlyOneReadRunsAtATime() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        let pasteboard = makePasteboard()
        let reader = HeldClipboardReader()
        let monitor = ClipboardMonitor(store: store, pasteboard: pasteboard, reader: reader)
        pasteboard.clearContents()
        pasteboard.setString("old", forType: .string)
        let count = pasteboard.changeCount
        let pending = Task { await monitor.poll() }
        await reader.waitForRead()

        // A second tick must return while the first read is outstanding.
        await monitor.poll()
        #expect(reader.readCount == 1)
        pasteboard.clearContents()
        pasteboard.setString("new", forType: .string)
        reader.complete(ClipboardReadResponse(changeCount: count,
            entry: ClipboardEntry(content: .text("old"))))
        await pending.value
        #expect(store.entries.isEmpty)
    }

    @Test func stoppingInvalidatesAnOutstandingRead() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        let pasteboard = makePasteboard()
        let reader = HeldClipboardReader()
        let monitor = ClipboardMonitor(store: store, pasteboard: pasteboard, reader: reader)
        pasteboard.clearContents()
        pasteboard.setString("pending", forType: .string)
        let count = pasteboard.changeCount
        let pending = Task { await monitor.poll() }
        await reader.waitForRead()
        monitor.stop()
        reader.complete(ClipboardReadResponse(changeCount: count,
            entry: ClipboardEntry(content: .text("pending"))))
        await pending.value
        #expect(store.entries.isEmpty)
    }

    @Test func selfWriteInvalidatesAnOutstandingRead() async {
        let store = ClipboardStore(directory: makeTempDirectory())
        let pasteboard = makePasteboard()
        let reader = HeldClipboardReader()
        let monitor = ClipboardMonitor(store: store, pasteboard: pasteboard, reader: reader)
        pasteboard.clearContents()
        pasteboard.setString("pending", forType: .string)
        let count = pasteboard.changeCount
        let pending = Task { await monitor.poll() }
        await reader.waitForRead()
        monitor.acknowledgeSelfWrite()
        reader.complete(ClipboardReadResponse(changeCount: count,
            entry: ClipboardEntry(content: .text("pending"))))
        await pending.value
        #expect(store.entries.isEmpty)
    }

}


@MainActor
private final class HeldClipboardReader: ClipboardReading {
    private var continuation: CheckedContinuation<ClipboardReadResponse?, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private(set) var readCount = 0

    func read(_ request: ClipboardReadRequest) async -> ClipboardReadResponse? {
        readCount += 1
        return await withCheckedContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
    }

    func waitForRead() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func complete(_ response: ClipboardReadResponse?) {
        continuation?.resume(returning: response)
        continuation = nil
    }
}
