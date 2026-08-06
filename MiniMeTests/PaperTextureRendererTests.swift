//
//  PaperTextureRendererTests.swift
//  MiniMeTests
//

import Testing
import AppKit
@testable import MiniMe

@MainActor
struct PaperTextureRendererTests {

    /// The tile is measured in points but drawn in device pixels, so a Retina
    /// screen gets twice the grains rather than one grain blown up to two pixels.
    @Test func aRetinaTileIsHalfItsPixelSizeInPoints() {
        PaperTextureRenderer.clearCache()

        let tile = PaperTextureRenderer.tile(for: .matte, scale: 2)

        #expect(tile.size.width == CGFloat(PaperTextureRenderer.tilePixelSize) / 2)
        #expect(tile.size.height == CGFloat(PaperTextureRenderer.tilePixelSize) / 2)
        #expect(tile.representations.first?.pixelsWide == PaperTextureRenderer.tilePixelSize)
    }

    @Test func aNonRetinaTileIsItsPixelSizeInPoints() {
        PaperTextureRenderer.clearCache()

        let tile = PaperTextureRenderer.tile(for: .matte, scale: 1)

        #expect(tile.size.width == CGFloat(PaperTextureRenderer.tilePixelSize))
        #expect(tile.representations.first?.pixelsWide == PaperTextureRenderer.tilePixelSize)
    }

    /// Rendering runs Core Image over half a megapixel. Doing that on every
    /// redraw of a full-screen window is the difference between a static overlay
    /// and a stutter.
    @Test func askingTwiceForTheSameTileReusesTheRenderedOne() {
        PaperTextureRenderer.clearCache()

        let first = PaperTextureRenderer.tile(for: .parchment, scale: 2)
        let second = PaperTextureRenderer.tile(for: .parchment, scale: 2)

        #expect(first === second)
    }

    @Test func eachTextureRendersItsOwnTile() {
        PaperTextureRenderer.clearCache()

        let matte = PaperTextureRenderer.tile(for: .matte, scale: 2)
        let vellum = PaperTextureRenderer.tile(for: .vellum, scale: 2)

        #expect(matte !== vellum)
    }

    /// Dragging a window between a Retina and a non-Retina display must not hand
    /// back the tile rendered for the other one.
    @Test func eachBackingScaleGetsItsOwnTile() {
        PaperTextureRenderer.clearCache()

        let retina = PaperTextureRenderer.tile(for: .matte, scale: 2)
        let standard = PaperTextureRenderer.tile(for: .matte, scale: 1)

        #expect(retina !== standard)
        #expect(retina.size.width != standard.size.width)
    }

    @Test func everyTextureRendersSomething() {
        PaperTextureRenderer.clearCache()

        for texture in PaperTexture.allCases {
            let tile = PaperTextureRenderer.tile(for: texture, scale: 2)
            #expect(tile.representations.first != nil)
        }
    }
}
