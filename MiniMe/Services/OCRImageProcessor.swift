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

    /// Vision's text detector is unstable on extreme-aspect strips (a thin, wide
    /// line of text): ±1px of input size can flip it between reading the whole
    /// line and silently dropping entire regions. Adding a small band of
    /// background above and below stabilizes detection. Returns the padding in
    /// pixels to add on each side, or 0 for normally shaped images.
    static func stripPadding(
        width: CGFloat,
        height: CGFloat,
        aspectThreshold: CGFloat,
        padding: CGFloat
    ) -> CGFloat {
        guard width > 0, height > 0, width / height > aspectThreshold else { return 0 }
        return padding
    }

    /// Extends `image` vertically by `padding` pixels on top and bottom, filled
    /// with the image's average color so the band blends with the background.
    static func paddedVertically(_ image: CGImage, by padding: CGFloat) -> CGImage {
        let pad = Int(padding.rounded())
        guard pad > 0 else { return image }

        guard let fill = averageColor(of: image) else { return image }

        let newHeight = image.height + 2 * pad
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.setFillColor(fill)
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: newHeight))
        context.draw(image, in: CGRect(x: 0, y: pad, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }

    /// Average color of the whole image, approximated by downscaling to 1x1.
    /// Text is sparse relative to background, so this lands near the background
    /// color without having to guess which pixels are background.
    private static func averageColor(of image: CGImage) -> CGColor? {
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = context.data else { return nil }
        let pixel = data.bindMemory(to: UInt8.self, capacity: 4)
        return CGColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
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
