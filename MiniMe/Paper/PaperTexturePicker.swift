//
//  PaperTexturePicker.swift
//  MiniMe
//

import SwiftUI

/// The texture chooser: one small live swatch per texture.
///
/// A segmented control was enough for three textures and is cramped at six, but
/// the real problem is that "Onionskin" and "Newsprint" mean nothing as words.
/// Each cell draws its own texture over the shared sample content at the
/// current strength, so the choice is made by looking rather than by guessing.
struct PaperTexturePicker: View {
    @Binding var selection: String
    let strength: Int

    /// Cells are laid out at this width, which is also what the grain tile is
    /// rendered for. See `cellWidth` below.
    private static let cellWidth: CGFloat = 132

    private var selected: PaperTexture {
        PaperTexture(rawValue: selection) ?? .matte
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Self.cellWidth), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(PaperTexture.allCases) { texture in
                Cell(
                    texture: texture,
                    strength: strength,
                    isSelected: texture == selected
                ) {
                    selection = texture.rawValue
                }
            }
        }
    }

    private struct Cell: View {
        let texture: PaperTexture
        let strength: Int
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                VStack(spacing: 5) {
                    ZStack {
                        // Not the full three-panel sample: at thumbnail size it
                        // is too busy to read a texture off. A dark field and a
                        // light one is what actually shows the difference — the
                        // grain and the lift on the dark half, the wash's
                        // colour on the light half.
                        HStack(spacing: 0) {
                            Color(white: 0.06)
                            Color.white.frame(width: 44)
                        }
                        // The tile has to be *rendered* at the cell's size, not
                        // just drawn small: the shipping tile is 512 device
                        // pixels, and resampling that down into a cell this
                        // narrow turns the grain into hard blocks.
                        PaperOverlayLayers(
                            texture: texture,
                            grainTilePoints: PaperTexturePicker.cellWidth
                        )
                        .opacity(PaperStrength.alpha(for: strength))
                    }
                    .frame(height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                    Text(texture.title)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(texture.title)
            .accessibilityValue(texture.summary)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }
}
