//
//  PaperTextureTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct PaperTextureTests {

    // MARK: - Cases

    @Test func hasTheSixShippingTextures() {
        #expect(Set(PaperTexture.allCases) == [
            .onionskin, .vellum, .matte, .linen, .newsprint, .parchment
        ])
    }

    /// These three shipped first and their raw values are already in people's
    /// preferences. Renaming one silently resets their choice to the default.
    @Test func theOriginalThreeKeepTheirStoredSpelling() {
        #expect(PaperTexture.matte.rawValue == "matte")
        #expect(PaperTexture.parchment.rawValue == "parchment")
        #expect(PaperTexture.vellum.rawValue == "vellum")
    }

    /// The picker is a grid of swatches read top-left to bottom-right, so the
    /// case order is what the user sees. It runs smoothest grain to coarsest,
    /// which is the axis people actually pick along — and the one Parchment sat
    /// at the wrong end of.
    @Test func texturesRunFromFinestGrainToCoarsest() {
        let coarseness = PaperTexture.allCases.map(\.grain.coarseness)
        #expect(coarseness == coarseness.sorted())
        #expect(Set(coarseness).count == coarseness.count, "two textures share a coarseness — one of them is redundant")
    }

    @Test func everyTextureHasATitle() {
        for texture in PaperTexture.allCases {
            #expect(!texture.title.isEmpty)
        }
    }

    /// The summary is the only thing under the picker explaining what a name
    /// like "Onionskin" actually looks like.
    @Test func everyTextureHasASummary() {
        for texture in PaperTexture.allCases {
            #expect(!texture.summary.isEmpty)
        }
    }

    /// The complaint that started this: Parchment's grain was coarse and
    /// high-contrast enough to read as blotches rather than paper.
    @Test func parchmentIsNoLongerTheCoarsestPossibleGrain() {
        #expect(PaperTexture.parchment.grain.coarseness <= 2.5)
        #expect(PaperTexture.parchment.grain.contrast <= 1.05)
    }

    /// Onionskin exists to be the one you can barely see. If its grain ever
    /// weighs as much as another texture's it has stopped doing its job.
    @Test func onionskinCarriesTheLightestGrain() {
        let others = PaperTexture.allCases.filter { $0 != .onionskin }
        for texture in others {
            #expect(PaperTexture.onionskin.grain.weight < texture.grain.weight)
        }
    }

    /// The raw value is what lands in UserDefaults, so a texture the user picked
    /// has to come back as itself after a relaunch.
    @Test func everyTextureRoundTripsThroughItsRawValue() {
        for texture in PaperTexture.allCases {
            #expect(PaperTexture(rawValue: texture.rawValue) == texture)
        }
    }

    @Test func anUnknownRawValueIsRejected() {
        #expect(PaperTexture(rawValue: "burlap") == nil)
    }

    // MARK: - Parameters

    /// The wash is drawn as a colour, so out-of-range components would be
    /// clamped by AppKit into a texture nobody designed.
    @Test func washComponentsAreWithinTheUnitRange() {
        for texture in PaperTexture.allCases {
            let wash = texture.wash
            #expect((0...1).contains(wash.red))
            #expect((0...1).contains(wash.green))
            #expect((0...1).contains(wash.blue))
            #expect((0...1).contains(wash.weight))
        }
    }

    /// Coarseness is an upscale factor for the noise. Below 1 it would downscale
    /// into aliasing rather than grain.
    @Test func grainCoarsenessIsAtLeastOne() {
        for texture in PaperTexture.allCases {
            #expect(texture.grain.coarseness >= 1)
        }
    }

    @Test func grainWeightIsWithinTheUnitRange() {
        for texture in PaperTexture.allCases {
            #expect((0...1).contains(texture.grain.weight))
        }
    }

    /// Wash and grain split one opacity budget. Together over 1 and the window's
    /// alpha stops being the thing the strength slider controls.
    @Test func washAndGrainWeightsShareOneBudget() {
        for texture in PaperTexture.allCases {
            #expect(texture.wash.weight + texture.grain.weight <= 1.0001)
        }
    }
}

struct PaperStrengthTests {

    /// The scale used to stop at 15%, on the assumption that anything fainter
    /// was invisible on most displays. It isn't on all of them, and the floor
    /// made the weakest setting a lie. Zero now means zero.
    @Test func theWeakestSettingIsFullyTransparent() {
        #expect(PaperStrength.alpha(for: 0) == 0)
    }

    @Test func theStrongestSettingIsThirtyPercent() {
        #expect(PaperStrength.alpha(for: 100) == 0.30)
    }

    @Test func theMidpointSitsHalfwayThroughTheRange() {
        #expect(abs(PaperStrength.alpha(for: 50) - 0.15) < 0.0001)
    }

    /// The ceiling is the clamp that still matters: past 30% the matte stops
    /// diffusing the screen and starts hiding it.
    @Test func noSettingCanRenderDarkerThanThirtyPercent() {
        for value in [0, 50, 100, 400, -30] {
            #expect(PaperStrength.alpha(for: value) <= 0.30)
        }
    }

    /// A stale or hand-edited defaults value must not produce a matte darker
    /// than the design allows — at high alpha the screen stops being readable.
    @Test func valuesAboveTheRangeClampToTheStrongestSetting() {
        #expect(PaperStrength.alpha(for: 400) == 0.30)
    }

    @Test func negativeValuesClampToTheWeakestSetting() {
        #expect(PaperStrength.alpha(for: -30) == 0)
    }

    @Test func theDefaultSitsInsideTheSliderRange() {
        #expect(PaperStrength.range.contains(PaperStrength.defaultValue))
    }

    // MARK: - What the slider prints

    /// The slider prints the opacity it renders. Now that the floor is gone the
    /// two happen to agree at the bottom of the scale — but they still differ
    /// everywhere else, which is why the label is derived rather than printed.
    @Test func theWeakestSettingPrintsZeroPercent() {
        #expect(PaperStrength.percentLabel(for: 0) == "0%")
    }

    @Test func theLabelDiffersFromTheSliderPositionInTheMiddle() {
        #expect(PaperStrength.percentLabel(for: 50) == "15%")
    }

    @Test func theStrongestSettingPrintsThirtyPercent() {
        #expect(PaperStrength.percentLabel(for: 100) == "30%")
    }

    /// Built from `alpha(for:)` rather than repeating its arithmetic, so the
    /// number on screen cannot drift from the opacity being rendered.
    @Test func theLabelAgreesWithTheRenderedAlpha() {
        for value in [0, 17, 50, 83, 100] {
            let rendered = Int((PaperStrength.alpha(for: value) * 100).rounded())
            #expect(PaperStrength.percentLabel(for: value) == "\(rendered)%")
        }
    }

    @Test func theLabelClampsAsTheAlphaDoes() {
        #expect(PaperStrength.percentLabel(for: 400) == "30%")
        #expect(PaperStrength.percentLabel(for: -30) == "0%")
    }
}
