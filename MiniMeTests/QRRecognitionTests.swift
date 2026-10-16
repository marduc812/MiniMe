import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import MiniMe

struct QRRecognitionTests {
    private let engine = OCREngine()

    @Test func decodesURLWithoutExtraText() throws {
        let payload = "https://example.com/path?name=Kimeno&value=42#details"
        #expect(engine.recognizeContent(in: try qrImage(payload)) == payload)
    }

    @Test func preservesPayloadWhitespaceAndLineBreaks() throws {
        let payload = "  first-\nsecond\n\n\nlast\t "
        #expect(engine.recognizeContent(in: try qrImage(payload)) == payload)
    }

    @Test func recognizesTextAndQRCodeTogether() throws {
        let payload = "https://example.com/scan"
        let image = try canvas(width: 700, height: 500) { context in
            let text = OCRTestSupport.renderText("Scan this code")
            context.draw(text, in: CGRect(x: 20, y: 390, width: text.width, height: text.height))
            let qr = try qrImage(payload)
            context.draw(qr, in: CGRect(x: 20, y: 20, width: qr.width, height: qr.height))
        }
        let result = engine.recognizeContent(in: image)
        #expect(result == "Scan this code\n" + payload)
    }

    @Test func decodesMultipleCodesInReadingOrder() throws {
        let top = "https://example.com/top"
        let bottom = "WIFI:T:WPA;S:Test Network;P:password;;"
        let image = try canvas(width: 500, height: 750) { context in
            for (payload, y) in [(top, 400), (bottom, 20)] {
                let qr = try qrImage(payload)
                context.draw(qr, in: CGRect(x: 20, y: y, width: qr.width, height: qr.height))
            }
        }
        #expect(engine.recognizeContent(in: image) == top + "\n" + bottom)
    }

    @Test func textOnlyCaptureStillWorks() {
        #expect(engine.recognizeContent(in: OCRTestSupport.renderText("Hello")) == "Hello")
    }

    @Test func blankCaptureReturnsNoContent() {
        #expect(engine.recognizeContent(in: OCRTestSupport.blankImage(width: 200, height: 200)).isEmpty)
    }

    private func qrImage(_ payload: String) throws -> CGImage {
        let filter = try #require(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let output = try #require(filter.outputImage)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        let code = try #require(CIContext().createCGImage(scaled, from: scaled.extent))
        // Include a quiet zone, as a screen snip normally would.
        return try canvas(width: code.width + 48, height: code.height + 48) { context in
            context.interpolationQuality = .none
            context.draw(code, in: CGRect(x: 24, y: 24, width: code.width, height: code.height))
        }
    }

    private func canvas(
        width: Int, height: Int, draw: (CGContext) throws -> Void
    ) rethrows -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        try draw(context)
        return context.makeImage()!
    }
}
