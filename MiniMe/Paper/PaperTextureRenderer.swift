//
//  PaperTextureRenderer.swift
//  MiniMe
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders a `PaperTexture`'s grain into a tile the overlay can repeat.
///
/// Generated rather than shipped as artwork: a texture is then a handful of
/// numbers in `PaperTexture` instead of a megabyte in the asset catalog, and
/// retuning one is a code change rather than a round trip through an image
/// editor. `CIRandomGenerator` is deterministic, so a texture looks the same on
/// every launch.
@MainActor
enum PaperTextureRenderer {
    /// Side length of a tile in device pixels. Big enough that the repeat isn't
    /// legible as a pattern, small enough to stay well inside a texture cache.
    ///
    /// `nonisolated` because it is the default for `tile(for:scale:pixelSize:)`,
    /// and a default argument is evaluated wherever the call is written — which
    /// need not be the main actor.
    static nonisolated let tilePixelSize = 512

    private struct CacheKey: Hashable {
        let texture: PaperTexture
        let scale: CGFloat
        let pixelSize: Int
    }

    private static var cache: [CacheKey: NSImage] = [:]

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// The tile for `texture` at a display's `backingScaleFactor`.
    ///
    /// Keyed by scale as well as texture: the tile is `pixelSize` device pixels,
    /// sized down in points to match, so grain stays per-pixel crisp on Retina
    /// instead of being one grain smeared across four pixels.
    ///
    /// `pixelSize` is only worth passing where the tile must repeat inside
    /// something far smaller than a display — see `PaperOverlayLayers`. Drawing
    /// the full-size tile into a fraction of its own pixel count resamples it on
    /// every repeat, and the grain lands as hard blocks.
    static func tile(
        for texture: PaperTexture,
        scale: CGFloat,
        pixelSize: Int = tilePixelSize
    ) -> NSImage {
        let pixels = max(pixelSize, 1)
        let key = CacheKey(texture: texture, scale: scale, pixelSize: pixels)
        if let cached = cache[key] { return cached }

        let rendered = render(texture, scale: scale, pixelSize: pixels)
        cache[key] = rendered
        return rendered
    }

    /// Drops every rendered tile. Used by tests; the app renders three tiles at
    /// most per scale factor and keeps them for the process lifetime.
    static func clearCache() {
        cache.removeAll()
    }

    // MARK: - Rendering

    private static func render(_ texture: PaperTexture, scale: CGFloat, pixelSize: Int) -> NSImage {
        let side = CGFloat(pixelSize)
        let points = NSSize(width: side / max(scale, 1), height: side / max(scale, 1))

        guard let cgImage = noiseImage(texture, pixelSize: pixelSize) else {
            return blankTile(size: points, pixelSize: pixelSize)
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = points

        let image = NSImage(size: points)
        image.addRepresentation(rep)
        return image
    }

    /// Noise generated small and blown back up: scaling is what turns per-pixel
    /// static into grains of a chosen size, and Lanczos leaves them with soft
    /// edges rather than the hard squares a nearest-neighbour scale would.
    private static func noiseImage(_ texture: PaperTexture, pixelSize: Int) -> CGImage? {
        let side = CGFloat(pixelSize)
        let coarseness = max(texture.grain.coarseness, 1)
        let sourceSide = max((side / coarseness).rounded(), 1)

        let generator = CIFilter.randomGenerator()
        guard let noise = generator.outputImage else { return nil }

        let cropped = noise.cropped(to: CGRect(x: 0, y: 0, width: sourceSide, height: sourceSide))

        let controls = CIFilter.colorControls()
        controls.inputImage = cropped
        controls.saturation = 0            // paper grain is tonal, not coloured
        controls.contrast = Float(texture.grain.contrast)
        controls.brightness = 0
        guard let monochrome = controls.outputImage else { return nil }

        let upscale = CIFilter.lanczosScaleTransform()
        upscale.inputImage = monochrome
        upscale.scale = Float(side / sourceSide)
        upscale.aspectRatio = 1
        guard let scaled = upscale.outputImage else { return nil }

        // The scale filter's extent can land a fraction short of the target.
        // Cropping to the exact square keeps the tile seamless when repeated.
        let exact = scaled.cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
        return context.createCGImage(exact, from: CGRect(x: 0, y: 0, width: side, height: side))
    }

    /// A transparent tile, so a Core Image failure costs the grain layer rather
    /// than leaving the overlay to draw an empty `NSImage` of unknown size.
    private static func blankTile(size: NSSize, pixelSize: Int) -> NSImage {
        let image = NSImage(size: size)
        if let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) {
            rep.size = size
            image.addRepresentation(rep)
        }
        return image
    }
}
