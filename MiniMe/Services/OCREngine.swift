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
    /// Target on-screen glyph/line height in pixels. When a first pass finds text
    /// smaller than this, the image is upscaled and recognized again — the single
    /// biggest win for large selections full of small text.
    var targetGlyphHeightPx: CGFloat = 32
    /// Upper bound on the longest side of the image handed to a recognition pass,
    /// so adaptive upscaling of a big selection can't blow up memory.
    var maxProcessedDimension: CGFloat = 4096

    static let `default` = OCROptions()

    /// Sentinel language setting that enables Vision's automatic detection.
    static let automaticLanguage = "automatic"

    /// Maps a stored language setting to a recognition configuration. The
    /// `automatic` sentinel (or an empty value) enables Vision's language
    /// detection; any specific language code constrains recognition to it, so the
    /// Settings picker actually takes effect.
    static func languageConfiguration(for setting: String) -> (automatic: Bool, languages: [String]) {
        if setting.isEmpty || setting == automaticLanguage {
            return (true, ["en-US"])
        }
        return (false, [setting])
    }
}

struct OCREngine {

    /// Recognizes text in `image`, returning the cleaned result (empty if none).
    func recognizeText(in image: CGImage, options: OCROptions = .default) -> String {
        // Apply the cheap small-crop upscale.
        let base = OCRImageProcessor.upscaled(
            image,
            toMinimumHeight: options.minimumUpscaleHeight,
            maxScale: options.maxUpscale
        )

        guard let first = performRecognition(on: base, options: options) else {
            return ""
        }

        var best = first

        // Adaptive second pass: if the recognized text is small, upscale the whole
        // image so glyphs reach a comfortable size for Vision and try again.
        let requestedScale = OCRImageProcessor.adaptiveScale(
            medianGlyphHeightPx: first.medianGlyphHeightPx,
            targetHeightPx: options.targetGlyphHeightPx,
            maxScale: options.maxUpscale
        )
        let scale = boundedScale(requestedScale, for: base, maxDimension: options.maxProcessedDimension)
        if scale > 1 {
            let upscaled = OCRImageProcessor.scaled(base, by: scale)
            if let second = performRecognition(on: upscaled, options: options),
               second.weightedConfidence >= first.weightedConfidence {
                best = second
            }
        }

        return OCRTextPostProcessor.clean(best.text)
    }

    /// Clamps `scale` so the resulting image's longest side stays within `maxDimension`.
    private func boundedScale(_ scale: CGFloat, for image: CGImage, maxDimension: CGFloat) -> CGFloat {
        let longestSide = CGFloat(max(image.width, image.height))
        guard longestSide > 0 else { return 1 }
        let allowed = maxDimension / longestSide
        return min(scale, max(1, allowed))
    }

    // MARK: - Recognition

    private struct RecognitionResult {
        let text: String
        /// Median line-box height in pixels, used to decide adaptive upscaling.
        let medianGlyphHeightPx: CGFloat
        /// Length-weighted mean top-candidate confidence, used to pick the better pass.
        let weightedConfidence: Double
    }

    private func performRecognition(on image: CGImage, options: OCROptions) -> RecognitionResult? {
        var result: RecognitionResult?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let text = options.lineAware
                ? Self.lineAwareText(from: observations)
                : Self.columnText(from: observations)

            result = RecognitionResult(
                text: text,
                medianGlyphHeightPx: Self.medianGlyphHeightPx(from: observations, imageHeight: CGFloat(image.height)),
                weightedConfidence: Self.weightedConfidence(from: observations)
            )
        }

        configure(request, with: options)

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCR failed: \(error.localizedDescription)")
            return nil
        }

        return result
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

    // MARK: - Measurements

    /// Median of each observation's bounding-box height, converted to pixels.
    private static func medianGlyphHeightPx(
        from observations: [VNRecognizedTextObservation],
        imageHeight: CGFloat
    ) -> CGFloat {
        let heights = observations
            .map { ($0.boundingBox.maxY - $0.boundingBox.minY) * imageHeight }
            .filter { $0 > 0 }
            .sorted()
        guard !heights.isEmpty else { return 0 }
        let mid = heights.count / 2
        return heights.count % 2 == 0 ? (heights[mid - 1] + heights[mid]) / 2 : heights[mid]
    }

    /// Length-weighted mean of the top candidate's confidence across observations.
    private static func weightedConfidence(from observations: [VNRecognizedTextObservation]) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let weight = Double(max(candidate.string.count, 1))
            weightedSum += Double(candidate.confidence) * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return 0 }
        return weightedSum / totalWeight
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
