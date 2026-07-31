//
//  CaptureScene.swift
//  MiniMe
//

import SwiftUI

/// Drag a selection over a window of text; it flashes; the text pops out as a
/// clipboard card.
struct CaptureScene: View {
    var body: some View {
        SceneStage(duration: 4.2, resting: 0.72) { beat in
            let grow = beat.ramp(0.12, 0.38)
            let flash = beat.ramp(0.38, 0.48)
            let selectionOpacity = beat.ramp(0.08, 0.12) * (1 - beat.ramp(0.48, 0.60))
            let card = beat.ramp(0.45, 0.58) * (1 - beat.ramp(0.88, 1.0))

            MiniDesktop {
                // The window being read from.
                VStack(alignment: .leading, spacing: 7) {
                    DesktopTextLine(width: 116)
                    DesktopTextLine(width: 84)
                    DesktopTextLine(width: 103)
                    DesktopTextLine(width: 61)
                }
                .padding(9)
                .frame(width: 132, height: 74, alignment: .topLeading)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .offset(x: 16, y: 18)

                // The marquee.
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18 + 0.27 * flash))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    )
                    .frame(width: 116 * grow, height: 48 * grow)
                    .opacity(selectionOpacity)
                    .offset(x: 24, y: 34)

                // The text, now on the clipboard.
                VStack(alignment: .leading, spacing: 4) {
                    DesktopTextLine(width: 40, opacity: 0.85, color: .black)
                    DesktopTextLine(width: 28, opacity: 0.85, color: .black)
                    DesktopTextLine(width: 34, opacity: 0.85, color: .black)
                }
                .padding(6)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                .scaleEffect(0.9 + 0.1 * card)
                .opacity(card)
                .offset(x: 138, y: 88 + 10 * (1 - card))
            }
        }
    }
}
