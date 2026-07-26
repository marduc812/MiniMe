//
//  ClipboardThumbnailer.swift
//  MiniMe
//

import AppKit
import QuickLookThumbnailing

/// Produces cached PNG previews for clipboard entries.
///
/// File thumbnails MUST be generated at capture time. Under App Sandbox the read
/// grant on a pasteboard file URL lasts only as long as the pasteboard read; a
/// path restored from `clipboard.json` after a relaunch carries no access, so a
/// lazily-generated preview would silently fail.
enum ClipboardThumbnailer {

    static let maxDimension: CGFloat = 240

    /// Downsamples `image` to fit within `maxDimension` on its longest edge and
    /// encodes it as PNG. Never upscales. Returns `nil` for a zero-sized image.
    static func pngData(from image: NSImage, fitting maxDimension: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, min(maxDimension / size.width, maxDimension / size.height))
        let width = Int(max(1, (size.width * scale).rounded()))
        let height = Int(max(1, (size.height * scale).rounded()))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    /// Encodes `image` as PNG at its native size.
    ///
    /// Routed through `pngData(from:fitting:)` with `maxDimension` set to the
    /// image's own largest edge, which makes the internal scale factor exactly 1
    /// (never upscales, never downscales). Going through `image.tiffRepresentation`
    /// instead picks up the NSImage backing store's display scale factor (e.g. 2x
    /// on Retina, captured via `lockFocus`), silently doubling the output pixel
    /// dimensions relative to `image.size` — the same pitfall `pngData` avoids by
    /// building an explicit pixel-sized bitmap rep.
    static func fullSizePNGData(from image: NSImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        return pngData(from: image, fitting: max(size.width, size.height))
    }

    /// A cached preview for a file: a real QuickLook thumbnail where one exists
    /// (images, PDF first pages, video frames), otherwise the system type icon —
    /// which is already the right answer for audio, archives, apps and source files.
    static func fileThumbnailData(for url: URL) async -> Data? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: maxDimension, height: maxDimension),
            scale: 2,
            representationTypes: .all
        )

        if let representation = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request) {
            let image = NSImage(cgImage: representation.cgImage,
                                size: representation.contentRect.size)
            if let data = pngData(from: image, fitting: maxDimension) {
                return data
            }
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return pngData(from: icon, fitting: maxDimension)
    }
}
