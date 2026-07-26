//
//  ClipboardThumbnailerTests.swift
//  MiniMeTests
//

import Testing
import AppKit
@testable import MiniMe

struct ClipboardThumbnailerTests {

    /// A solid-colour image of an exact pixel size.
    private func makeImage(width: Int, height: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    private func pixelSize(of data: Data) -> CGSize? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    @Test func wideImageIsDownsampledOnTheLongEdge() throws {
        let data = try #require(ClipboardThumbnailer.pngData(from: makeImage(width: 1000, height: 500), fitting: 240))
        let size = try #require(pixelSize(of: data))

        #expect(size.width == 240)
        #expect(size.height == 120)
    }

    @Test func tallImageIsDownsampledOnTheLongEdge() throws {
        let data = try #require(ClipboardThumbnailer.pngData(from: makeImage(width: 500, height: 1000), fitting: 240))
        let size = try #require(pixelSize(of: data))

        #expect(size.width == 120)
        #expect(size.height == 240)
    }

    @Test func smallImageIsNotUpscaled() throws {
        let data = try #require(ClipboardThumbnailer.pngData(from: makeImage(width: 64, height: 32), fitting: 240))
        let size = try #require(pixelSize(of: data))

        #expect(size.width == 64)
        #expect(size.height == 32)
    }

    @Test func zeroSizedImageReturnsNil() {
        let empty = NSImage(size: .zero)
        #expect(ClipboardThumbnailer.pngData(from: empty, fitting: 240) == nil)
    }

    @Test func fullSizeEncodingPreservesPixelDimensions() throws {
        let image = makeImage(width: 300, height: 200)
        let expected = try #require(image.representations.first)
        let data = try #require(ClipboardThumbnailer.fullSizePNGData(from: image))
        let size = try #require(pixelSize(of: data))

        #expect(Int(size.width) == expected.pixelsWide)
        #expect(Int(size.height) == expected.pixelsHigh)
        // Full-size encoding must not downsample a Retina-backed source.
        #expect(size.width >= 300)
        #expect(size.height >= 200)
    }

    @Test func fileThumbnailFallsBackToAnIconForAnyExistingFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumbnailer-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = await ClipboardThumbnailer.fileThumbnailData(for: url)

        // Either a QuickLook preview or the system type icon — never nil for a
        // file that exists.
        #expect(data != nil)
    }
}
