//
//  OCRTestSupport.swift
//  MiniMeTests
//
//  Shared helpers for OCR tests: creating blank images and rendering text
//  into deterministic bitmaps so we can assert on recognition results.
//

import AppKit
import CoreGraphics
import Foundation

enum OCRTestSupport {

    /// Creates a blank opaque CGImage of the given pixel size.
    static func blankImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// Renders black text on a white background into a CGImage sized to fit.
    /// Used to produce deterministic inputs for the Vision-backed engine tests.
    static func renderText(
        _ string: String,
        fontSize: CGFloat = 48,
        padding: CGFloat = 20
    ) -> CGImage {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let textSize = attributed.size()

        let width = Int(ceil(textSize.width + padding * 2))
        let height = Int(ceil(textSize.height + padding * 2))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        attributed.draw(at: NSPoint(x: padding, y: padding))
        NSGraphicsContext.restoreGraphicsState()

        return context.makeImage()!
    }

    /// Renders multiple lines of black text stacked top-to-bottom on white.
    /// Used to verify line-aware ordering in the OCR engine.
    static func renderLines(
        _ lines: [String],
        fontSize: CGFloat = 48,
        padding: CGFloat = 20
    ) -> CGImage {
        let font = NSFont.systemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(
            string: lines.joined(separator: "\n"),
            attributes: attributes
        )
        let textSize = attributed.size()

        let width = Int(ceil(textSize.width + padding * 2))
        let height = Int(ceil(textSize.height + padding * 2))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        attributed.draw(in: CGRect(
            x: padding,
            y: padding,
            width: textSize.width,
            height: textSize.height
        ))
        NSGraphicsContext.restoreGraphicsState()

        return context.makeImage()!
    }
}
