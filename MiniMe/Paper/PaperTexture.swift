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
/// Case order is picker order, and it runs from the finest grain to the
/// coarsest — the axis people actually choose along.
enum PaperTexture: String, CaseIterable, Identifiable, Sendable {
    case onionskin
    case vellum
    case matte
    case linen
    case parchment
    case newsprint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onionskin: return "Onionskin"
        case .vellum:    return "Vellum"
        case .matte:     return "Matte"
        case .linen:     return "Linen"
        case .parchment: return "Parchment"
        case .newsprint: return "Newsprint"
        }
    }

    /// The one-line description shown under the texture picker.
    var summary: String {
        switch self {
        case .onionskin: return "Barely there — softens the screen with almost no grain."
        case .vellum:    return "Cool and almost smooth, a hint of tooth."
        case .matte:     return "Neutral and fine — takes the shine off without changing colour."
        case .linen:     return "Warm and lightly woven, between Matte and Parchment."
        case .parchment: return "Warm and soft-grained, like a printed stock."
        case .newsprint: return "Grey and flat, the coarsest of the set — cheap paper."
        }
    }

    var wash: PaperWash {
        switch self {
        case .onionskin:
            return PaperWash(red: 0.97, green: 0.97, blue: 0.96, weight: 0.40)
        case .vellum:
            return PaperWash(red: 0.93, green: 0.95, blue: 0.99, weight: 0.60)
        case .matte:
            return PaperWash(red: 0.96, green: 0.96, blue: 0.95, weight: 0.55)
        case .linen:
            return PaperWash(red: 0.97, green: 0.95, blue: 0.91, weight: 0.57)
        case .parchment:
            return PaperWash(red: 0.98, green: 0.93, blue: 0.83, weight: 0.60)
        case .newsprint:
            return PaperWash(red: 0.90, green: 0.90, blue: 0.88, weight: 0.58)
        }
    }

    var grain: PaperGrain {
        switch self {
        case .onionskin:
            return PaperGrain(coarseness: 1.10, contrast: 0.55, weight: 0.18)
        case .vellum:
            return PaperGrain(coarseness: 1.15, contrast: 0.70, weight: 0.40)
        case .matte:
            return PaperGrain(coarseness: 1.60, contrast: 0.85, weight: 0.45)
        case .linen:
            return PaperGrain(coarseness: 2.00, contrast: 0.95, weight: 0.40)
        // Was 3.2 / 1.15 / 0.38, which read as blotches rather than paper.
        case .parchment:
            return PaperGrain(coarseness: 2.20, contrast: 1.00, weight: 0.34)
        case .newsprint:
            return PaperGrain(coarseness: 2.40, contrast: 0.75, weight: 0.42)
        }
    }
}

/// Maps the 0–100 strength slider onto the overlay window's opacity.
///
/// The range stops at 30%: past that the matte stops diffusing the screen and
/// starts hiding it. That ceiling is the clamp that matters, and the reason
/// `alpha(for:)` guards against a hand-edited preference at all.
///
/// It used to stop at 15% too, on the grounds that anything fainter was
/// invisible on most displays and would read as a broken tool. That floor
/// asserted something about the user's hardware that isn't true on all of it,
/// and it made the weakest setting print a number it wasn't rendering. Zero
/// now means zero: an invisible matte is a legitimate thing to ask for, and
/// Settings says so rather than quietly substituting 15%.
enum PaperStrength {
    static let minAlpha = 0.0
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

    /// What the slider prints: the opacity actually rendered, not the slider's
    /// own position.
    ///
    /// The two are not the same number. The slider runs 0–100 across a 15%–30%
    /// band, so printing its raw position labelled the weakest setting "0%"
    /// over a matte that was plainly visible. Derived from `alpha(for:)` so the
    /// label cannot drift from what is on screen.
    static func percentLabel(for value: Int) -> String {
        "\(Int((alpha(for: value) * 100).rounded()))%"
    }
}
