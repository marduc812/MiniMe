//
//  OCRFixtureLoader.swift
//  MiniMeTests
//
//  Loads the OCR regression corpus (ocr-fixtures.json + PNGs) from the test bundle.
//

import AppKit
import CoreGraphics
import Foundation

/// Marker used to resolve the test bundle that contains the fixtures.
private final class OCRFixtureBundleMarker {}

struct OCRFixture: Decodable {
    let image: String
    let mustContain: [String]

    /// Loads the fixture's PNG from the test bundle as a CGImage.
    func loadCGImage() -> CGImage? {
        let bundle = Bundle(for: OCRFixtureBundleMarker.self)
        let name = (image as NSString).deletingPathExtension
        let ext = (image as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else {
            return nil
        }
        return rep.cgImage
    }
}

enum OCRFixtureLoader {
    private struct Manifest: Decodable {
        let fixtures: [OCRFixture]
    }

    enum LoaderError: Error, CustomStringConvertible {
        case manifestNotFound

        var description: String {
            switch self {
            case .manifestNotFound:
                return "ocr-fixtures.json not found in the test bundle"
            }
        }
    }

    static func loadAll() throws -> [OCRFixture] {
        let bundle = Bundle(for: OCRFixtureBundleMarker.self)
        guard let url = bundle.url(forResource: "ocr-fixtures", withExtension: "json") else {
            throw LoaderError.manifestNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Manifest.self, from: data).fixtures
    }
}
