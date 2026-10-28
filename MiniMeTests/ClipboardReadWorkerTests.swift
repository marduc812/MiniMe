import AppKit
import Testing
@testable import MiniMe

struct ClipboardReadWorkerTests {
    @Test func rejectsOversizedDimensionsWithoutDecodingPixels() {
        #expect(!ClipboardReadWorker.acceptsImageDimensions(width: 10000, height: 6000))
        #expect(!ClipboardReadWorker.acceptsImageDimensions(width: Int.max, height: Int.max))
        #expect(!ClipboardReadWorker.acceptsImageDimensions(width: 100, height: 0))
        #expect(ClipboardReadWorker.acceptsImageDimensions(width: 4000, height: 3000))
        #expect(ClipboardReadWorker.acceptsImageDimensions(width: 6016, height: 3384))
        #expect(ClipboardReadWorker.acceptsImageDimensions(width: 7680, height: 4320))
    }

    @Test func pngKeepsItsOriginalBytesAndPixelDimensions() throws {
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: 16, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        memset(rep.bitmapData!, 0, rep.bytesPerRow * rep.pixelsHigh)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        let prepared = try #require(ClipboardReadWorker.prepareImage(data))
        #expect(prepared.png == data)
        #expect(prepared.width == 16)
        #expect(prepared.height == 8)
        #expect(prepared.thumbnail != nil)
    }

    @Test func malformedImageIsSkipped() {
        #expect(ClipboardReadWorker.prepareImage(Data("not an image".utf8)) == nil)
    }
}
