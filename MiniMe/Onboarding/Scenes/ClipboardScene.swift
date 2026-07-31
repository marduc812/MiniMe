//
//  ClipboardScene.swift
//  MiniMe
//

import SwiftUI

/// The picker slides up, the highlight walks down the history, one entry is
/// taken and lands in the field above.
struct ClipboardScene: View {
    private let rowHeight: CGFloat = 14
    private let rowStride: CGFloat = 19

    var body: some View {
        SceneStage(duration: 5.5, resting: 0.88) { beat in
            let panelY = 90 * (1 - beat.ramp(0.06, 0.18)) + 90 * beat.ramp(0.66, 0.80)
            let highlightRow = beat.ramp(0.26, 0.38) + beat.ramp(0.38, 0.52)
            let highlightOpacity = 0.75 * beat.ramp(0.20, 0.26) * (1 - beat.ramp(0.64, 0.68))
            let pasted = beat.ramp(0.78, 0.84) * (1 - beat.ramp(0.94, 1.0))

            MiniDesktop {
                // Where the entry ends up.
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.32), lineWidth: 1.5)
                    .frame(width: 170, height: 24)
                    .offset(x: 22, y: 16)

                DesktopTextLine(width: 120 * pasted, opacity: 1, color: .accentColor)
                    .offset(x: 30, y: 26)

                // The picker.
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 5) {
                        ForEach([0.60, 0.44, 0.72, 0.38], id: \.self) { fraction in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white.opacity(0.13))
                                .frame(height: rowHeight)
                                .overlay(alignment: .leading) {
                                    DesktopTextLine(width: 170 * fraction, opacity: 0.5)
                                        .padding(.leading, 6)
                                }
                        }
                    }
                    .padding(8)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 170, height: rowHeight)
                        .opacity(highlightOpacity)
                        .offset(x: 8, y: 8 + rowStride * highlightRow)
                }
                .frame(width: 186, height: 84, alignment: .topLeading)
                .background(.white.opacity(0.16))
                .clipShape(
                    UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7, style: .continuous)
                )
                .offset(x: 14, y: 50 + panelY)
            }
        }
    }
}
