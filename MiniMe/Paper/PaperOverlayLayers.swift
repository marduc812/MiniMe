//
//  PaperOverlayLayers.swift
//  MiniMe
//

import SwiftUI

/// The matte itself: a wash with grain over it, at their designed weights and
/// nothing else.
///
/// One definition of the look, used by both the full-screen overlay window and
/// the Settings preview — so what the swatch shows is what the screen gets,
/// rather than two drawings that agree until one of them is edited. Overall
/// strength is applied by whoever hosts this: the window through its
/// `alphaValue`, the swatch through `.opacity`.
struct PaperOverlayLayers: View {
    let texture: PaperTexture

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            Color(
                .sRGB,
                red: texture.wash.red,
                green: texture.wash.green,
                blue: texture.wash.blue
            )
            .opacity(texture.wash.weight)

            Image(nsImage: PaperTextureRenderer.tile(for: texture, scale: displayScale))
                .resizable(resizingMode: .tile)
                .opacity(texture.grain.weight)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Sample content under the matte, for judging a texture and strength without
/// putting them on the whole screen.
///
/// The three blocks are chosen to show what the matte actually does: it lifts a
/// dark field, dulls a saturated one, and leaves light text legible.
struct PaperSwatch: View {
    let texture: PaperTexture
    let strength: Int

    var body: some View {
        ZStack {
            sampleContent
            PaperOverlayLayers(texture: texture)
                .opacity(PaperStrength.alpha(for: strength))
        }
        .frame(height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .accessibilityLabel("Preview of \(texture.title) at \(strength) percent")
    }

    private var sampleContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach([54.0, 40.0, 48.0], id: \.self) { width in
                    Capsule()
                        .fill(.black.opacity(0.75))
                        .frame(width: width, height: 5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)

            Color.black
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.red, .orange, .cyan],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
