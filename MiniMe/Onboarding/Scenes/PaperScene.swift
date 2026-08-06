//
//  PaperScene.swift
//  MiniMe
//

import SwiftUI

/// A sheet of paper is drawn across the display, dulling the bright block it
/// passes over and leaving the text underneath still readable.
struct PaperScene: View {
    var body: some View {
        SceneStage(duration: 5.0, resting: 0.72) { beat in
            let wipe = beat.ramp(0.12, 0.58)

            MiniDesktop {
                DesktopTextLine(width: 96).offset(x: 18, y: 26)
                DesktopTextLine(width: 72).offset(x: 18, y: 38)
                DesktopTextLine(width: 88).offset(x: 18, y: 50)

                LinearGradient(
                    colors: [.orange, .pink, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 76, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .offset(x: 18, y: 72)

                sheet(covering: wipe)
            }
        }
    }

    /// The real overlay, clipped to the leading `fraction` of the mock screen so
    /// it reads as a sheet being drawn across.
    ///
    /// Carried at more than its shipping strength: a 20% matte on a 214-point
    /// desktop is invisible.
    private func sheet(covering fraction: Double) -> some View {
        PaperOverlayLayers(texture: .parchment)
            .opacity(0.5)
            .clipShape(LeadingWipe(fraction: fraction))
    }
}

/// The leading `fraction` of whatever it is applied to.
private struct LeadingWipe: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height))
    }
}
