//
//  OCRImageProcessor.swift
//  MiniMe
//
//  Pre-processing for OCR. The single biggest win for on-screen text is
//  upscaling small selections before handing them to Vision: the recognizer
//  needs enough pixels per glyph, and a tight crop of standard-DPI text often
//  falls below that threshold.
//

import CoreGraphics

enum OCRImageProcessor {

    /// Scales `image` up so it is at least `minimumHeight` pixels tall, preserving
    /// aspect ratio. The scale factor is capped at `maxScale` to avoid excessive
    /// interpolation blur. Images already tall enough are returned unchanged.
    static func upscaled(
        _ image: CGImage,
        toMinimumHeight minimumHeight: CGFloat,
        maxScale: CGFloat = 4
    ) -> CGImage {
        let height = CGFloat(image.height)
        guard height > 0, height < minimumHeight else { return image }

        let scale = min(minimumHeight / height, maxScale)
        let newWidth = Int((CGFloat(image.width) * scale).rounded())
        let newHeight = Int((height * scale).rounded())

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    /// Scales `image` by an explicit factor, preserving aspect ratio and using
    /// high-quality interpolation. A factor <= 1 returns the image unchanged.
    static func scaled(_ image: CGImage, by factor: CGFloat) -> CGImage {
        guard factor > 1 else { return image }

        let newWidth = Int((CGFloat(image.width) * factor).rounded())
        let newHeight = Int((CGFloat(image.height) * factor).rounded())

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    /// Decides how much to upscale so glyphs reach a comfortable pixel height for
    /// Vision. Returns 1 (no scaling) when glyphs are already tall enough or the
    /// measurement is unavailable; otherwise `target / median`, capped at `maxScale`.
    static func adaptiveScale(
        medianGlyphHeightPx: CGFloat,
        targetHeightPx: CGFloat,
        maxScale: CGFloat
    ) -> CGFloat {
        guard medianGlyphHeightPx > 0, medianGlyphHeightPx < targetHeightPx else { return 1 }
        return min(targetHeightPx / medianGlyphHeightPx, maxScale)
    }
}
