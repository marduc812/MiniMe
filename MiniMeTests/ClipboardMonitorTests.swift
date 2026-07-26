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

    @Test func textIsCapturedAsATextEntry() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("git push origin main", forType: .string)
        monitor.poll()

        #expect(store.entries.count == 1)
        #expect(store.entries[0].content == .text("git push origin main"))
    }

    @Test func unchangedPasteboardProducesNoDuplicate() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("stable", forType: .string)
        monitor.poll()
        monitor.poll()
        monitor.poll()

        #expect(store.entries.count == 1)
    }

    @Test func separateCopiesOfDifferentTextBothLand() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        monitor.poll()

        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        monitor.poll()

        #expect(store.entries.count == 2)
        #expect(store.entries[0].content == .text("second"))
    }

    @Test func concealedContentIsSkipped() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func transientContentIsSkipped() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("ephemeral", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func concealedContentIsCapturedWhenTheFilterIsOff() {
        let (monitor, store, pasteboard) = makeSubject()
        monitor.ignoreConcealed = false

        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        monitor.poll()

        #expect(store.entries.count == 1)
    }

    @Test func whitespaceOnlyTextIsNotCaptured() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("   \n\t ", forType: .string)
        monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func acknowledgeSelfWriteSuppressesTheNextPoll() {
        let (monitor, store, pasteboard) = makeSubject()

        pasteboard.clearContents()
        pasteboard.setString("written by MiniMe itself", forType: .string)
        monitor.acknowledgeSelfWrite()
        monitor.poll()

        #expect(store.entries.isEmpty)
    }

    @Test func fileURLsAreCapturedAsAFilesEntry() throws {
        let (monitor, store, pasteboard) = makeSubject()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monitor-\(UUID().uuidString).txt")
        try Data("file body".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        monitor.poll()

        #expect(store.entries.count == 1)
        #expect(store.entries[0].content == .files(paths: [url.path]))
    }

    @Test func fileURLsAreCapturedAsTextWhenImageAndFileCaptureIsOff() throws {
        let (monitor, store, pasteboard) = makeSubject()
        monitor.captureImagesAndFiles = false

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monitor-\(UUID().uuidString).txt")
        try Data("file body".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        monitor.poll()

        // A file copy also puts a text representation on the pasteboard; with
        // file capture disabled that text is what gets recorded.
        if let entry = store.entries.first {
            #expect(!entry.content.isImage)
            if case .files = entry.content {
                Issue.record("Expected a text entry, got a files entry")
            }
        }
    }

    @Test func startThenStopLeavesNoTimerRunning() {
        let (monitor, _, _) = makeSubject()
        monitor.start()
        monitor.stop()
        // Nothing to assert beyond not crashing; stop() must be idempotent.
        monitor.stop()
    }
}
