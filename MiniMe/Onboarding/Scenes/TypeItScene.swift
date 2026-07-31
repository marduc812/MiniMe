//
//  TypeItScene.swift
//  MiniMe
//

import SwiftUI

/// The clipboard card flashes, a countdown ring closes, then the text types
/// itself in character by character.
struct TypeItScene: View {
    /// Width of one "character", so the fill advances in visible steps rather
    /// than gliding — a glide reads as a progress bar, not as typing.
    private let step: CGFloat = 10

    var body: some View {
        SceneStage(duration: 5.0, resting: 0.85) { beat in
            let card = 1 + 0.12 * beat.pulse(0.08, 0.16, 0.28)
            let countdown = 1 - beat.ramp(0.20, 0.26)
            let reset = 1 - beat.ramp(0.92, 1.0)
            let firstLine = typed(chars: 14, progress: beat.ramp(0.24, 0.52)) * reset
            let secondLine = typed(chars: 9, progress: beat.ramp(0.52, 0.74)) * reset
            let onFirstLine = beat.t < 0.53

            MiniDesktop {
                // The source, on the clipboard.
                VStack(alignment: .leading, spacing: 3) {
                    DesktopTextLine(width: 32, opacity: 0.85, color: .black)
                    DesktopTextLine(width: 22, opacity: 0.85, color: .black)
                }
                .padding(5)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .shadow(color: Color.accentColor.opacity(card > 1.01 ? 0.9 : 0), radius: 6)
                .scaleEffect(card)
                .offset(x: 22, y: 18)

                // Countdown before typing starts.
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(1 - 0.3 * beat.ramp(0, 0.20))
                    .opacity(countdown)
                    .offset(x: 178, y: 16)

                // The field that won't take a paste.
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                    .frame(width: 170, height: 44)
                    .offset(x: 22, y: 52)

                DesktopTextLine(width: firstLine, opacity: 1, color: .accentColor)
                    .offset(x: 31, y: 64)
                DesktopTextLine(width: secondLine, opacity: 1, color: .accentColor)
                    .offset(x: 31, y: 78)

                Rectangle()
                    .fill(.white)
                    .frame(width: 1.5, height: 9)
                    .opacity(reset)
                    .offset(
                        x: 31 + (onFirstLine ? firstLine : secondLine),
                        y: onFirstLine ? 62 : 76
                    )
            }
        }
    }

    /// Quantises a 0…1 progress into whole characters.
    private func typed(chars: Int, progress: Double) -> CGFloat {
        (Double(chars) * progress).rounded(.down) * step
    }
}
