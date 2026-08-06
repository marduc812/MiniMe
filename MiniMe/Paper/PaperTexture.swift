//
//  PaperTexture.swift
//  MiniMe
//

import CoreGraphics

/// The flat colour laid over the screen — what lifts blacks and takes the edge
/// off highlights. Components are sRGB in 0...1.
///
/// `weight` is this layer's share of the overlay's opacity, not an absolute
/// alpha: the strength slider scales the whole window on top of it.
struct PaperWash: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let weight: Double
}

/// The noise laid over the wash.
///
/// `coarseness` is how far the generated noise is blown up before it is tiled —
/// 1 gives grain the size of a pixel, higher values give the soft blotches of a
/// heavier stock.
struct PaperGrain: Equatable, Sendable {
    let coarseness: CGFloat
    let contrast: Double
    let weight: Double
}

/// A paper surface, as the numbers that describe it.
///
/// Deliberately free of drawing code: this is the file to edit when a texture
/// looks wrong, and nothing here can break how the overlay is rendered. The raw
/// values are persisted, so don't rename a case without a migration.
enum PaperTexture: String, CaseIterable, Identifiable, Sendable {
    case matte
    case parchment
    case vellum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .matte:     return "Matte"
        case .parchment: return "Parchment"
        case .vellum:    return "Vellum"
        }
    }

    /// The one-line description shown under the texture picker.
    var summary: String {
        switch self {
        case .matte:     return "Neutral and fine — takes the shine off without changing colour."
        case .parchment: return "Warm and coarse, like a heavy printed stock."
        case .vellum:    return "Cool and almost smooth, the lightest of the three."
        }
    }

    var wash: PaperWash {
        switch self {
        case .matte:
            return PaperWash(red: 0.96, green: 0.96, blue: 0.95, weight: 0.55)
        case .parchment:
            return PaperWash(red: 0.98, green: 0.92, blue: 0.80, weight: 0.62)
        case .vellum:
            return PaperWash(red: 0.93, green: 0.95, blue: 0.99, weight: 0.60)
        }
    }

    var grain: PaperGrain {
        switch self {
        case .matte:
            return PaperGrain(coarseness: 1.6, contrast: 0.85, weight: 0.45)
        case .parchment:
            return PaperGrain(coarseness: 3.2, contrast: 1.15, weight: 0.38)
        case .vellum:
            return PaperGrain(coarseness: 1.15, contrast: 0.70, weight: 0.40)
        }
    }
}

/// Maps the 0–100 strength slider onto the overlay window's opacity.
///
/// The range stops at 30%: past that the matte stops diffusing the screen and
/// starts hiding it. It starts at 15% because anything fainter is invisible on
/// most displays, which reads as the tool being broken rather than subtle.
enum PaperStrength {
    static let minAlpha = 0.15
    static let maxAlpha = 0.30

    static let range = 0...100
    static let defaultValue = 50

    /// Clamped, because the value comes from `UserDefaults` — a stale or
    /// hand-edited number must not be able to black out the screen.
    static func alpha(for value: Int) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let fraction = Double(clamped) / Double(range.upperBound)
        return minAlpha + (maxAlpha - minAlpha) * fraction
    }
}
