//
//  PaperTextureTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct PaperTextureTests {

    // MARK: - Cases

    @Test func hasTheThreeShippingTextures() {
        #expect(Set(PaperTexture.allCases) == [.matte, .parchment, .vellum])
    }

    @Test func everyTextureHasATitle() {
        for texture in PaperTexture.allCases {
            #expect(!texture.title.isEmpty)
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

    @Test func theWeakestSettingIsFifteenPercent() {
        #expect(PaperStrength.alpha(for: 0) == 0.15)
    }

    @Test func theStrongestSettingIsThirtyPercent() {
        #expect(PaperStrength.alpha(for: 100) == 0.30)
    }

    @Test func theMidpointSitsHalfwayThroughTheRange() {
        #expect(abs(PaperStrength.alpha(for: 50) - 0.225) < 0.0001)
    }

    /// A stale or hand-edited defaults value must not produce a matte darker
    /// than the design allows — at high alpha the screen stops being readable.
    @Test func valuesAboveTheRangeClampToTheStrongestSetting() {
        #expect(PaperStrength.alpha(for: 400) == 0.30)
    }

    @Test func negativeValuesClampToTheWeakestSetting() {
        #expect(PaperStrength.alpha(for: -30) == 0.15)
    }

    @Test func theDefaultSitsInsideTheSliderRange() {
        #expect(PaperStrength.range.contains(PaperStrength.defaultValue))
    }
}
