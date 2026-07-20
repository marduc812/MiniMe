//
//  OCREngine.swift
//  MiniMe
//
//  Standalone, testable text recognition built on Apple's Vision framework.
//  Extracted from ScreenCaptureManager so it can be exercised directly against
//  images in unit tests and tuned independently of the capture pipeline.
//

import CoreGraphics
import Vision

struct OCROptions {
    /// Preferred recognition languages (used when automatic detection is off).
    var languages: [String] = ["en-US"]
    /// Let Vision pick the language. More robust when on-screen text isn't the
    /// user's configured language; falls back to `languages` when unavailable.
    var automaticallyDetectsLanguage: Bool = true
    /// Language correction fixes natural-language typos but mangles code, URLs,
    /// IDs and other technical strings — so it defaults to off for a screen-OCR tool.
    var usesLanguageCorrection: Bool = false
    /// Accuracy vs. speed. Accurate is strongly preferred for small text.
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    /// Group observations into visual lines and read left-to-right, top-to-bottom.
    var lineAware: Bool = true
    /// Small crops are upscaled to at least this pixel height before recognition.
    var minimumUpscaleHeight: CGFloat = 80
    /// Cap on the upscale factor to avoid excessive interpolation blur.
    var maxUpscale: CGFloat = 4
    /// Ignore text shorter than this fraction of image height (0 = detect all).
    var minimumTextHeight: Float = 0

    static let `default` = OCROptions()
}

struct OCREngine {

    /// Recognizes text in `image`, returning the joined result (empty if none).
    func recognizeText(in image: CGImage, options: OCROptions = .default) -> String {
        let processed = OCRImageProcessor.upscaled(
            image,
            toMinimumHeight: options.minimumUpscaleHeight,
            maxScale: options.maxUpscale
        )

        var resultText = ""

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            resultText = options.lineAware
                ? Self.lineAwareText(from: observations)
                : Self.columnText(from: observations)
        }

        configure(request, with: options)

        let handler = VNImageRequestHandler(cgImage: processed, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCR failed: \(error.localizedDescription)")
            return ""
        }

        return resultText
    }

    private func configure(_ request: VNRecognizeTextRequest, with options: OCROptions) {
        // Pin to the newest revision available at runtime for best accuracy.
        let supported = VNRecognizeTextRequest.supportedRevisions
        if let latest = supported.max() {
            request.revision = latest
        }

        request.recognitionLevel = options.recognitionLevel
        request.usesLanguageCorrection = options.usesLanguageCorrection
        request.minimumTextHeight = options.minimumTextHeight

        if options.automaticallyDetectsLanguage {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = options.languages
        }
    }

    // MARK: - Observation ordering

    private struct TextItem {
        let text: String
        let minX: CGFloat
        let midY: CGFloat
        let height: CGFloat
    }

    /// Groups observations into visual lines and reads left-to-right, top-to-bottom.
    private static func lineAwareText(from observations: [VNRecognizedTextObservation]) -> String {
        let items: [TextItem] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return TextItem(
                text: text,
                minX: box.minX,
                midY: (box.minY + box.maxY) / 2,
                height: box.maxY - box.minY
            )
        }

        var lines: [(items: [(text: String, minX: CGFloat)], midY: CGFloat, height: CGFloat)] = []
        for item in items {
            var foundLineIndex: Int?
            for (index, line) in lines.enumerated() {
                if abs(item.midY - line.midY) < line.height * 0.5 {
                    foundLineIndex = index
                    break
                }
            }
            if let index = foundLineIndex {
                lines[index].items.append((item.text, item.minX))
            } else {
                lines.append(([(item.text, item.minX)], item.midY, item.height))
            }
        }

        // Vision uses a bottom-left origin, so larger midY means higher on screen.
        let sortedLines = lines.sorted { $0.midY > $1.midY }
        return sortedLines.map { line in
            line.items.sorted { $0.minX < $1.minX }
                .map { $0.text }
                .joined(separator: " ")
        }.joined(separator: "\n")
    }

    /// Raw Vision ordering, one observation per line.
    private static func columnText(from observations: [VNRecognizedTextObservation]) -> String {
        observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
