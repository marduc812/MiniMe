//
//  PaperScene.swift
//  MiniMe
//

import SwiftUI

/// A sheet of paper is drawn halfway across a bright page and left there, so the
/// covered and bare halves sit side by side and the difference is the point.
struct PaperScene: View {

    /// Where the sheet stops, as a fraction of the mock screen.
    private static let coverage = 0.5

    /// Points across for one grain tile. The mock desktop is ~214 wide, so the
    /// shipping 512-pixel tile would cover almost all of it; at 28 the grain
    /// repeats often enough to read as paper rather than as one blotch, and
    /// small enough that the specks stay specks.
    private static let grainTilePoints: CGFloat = 28

    var body: some View {
        SceneStage(duration: 5.0, resting: 0.72) { beat in
            let wipe = Self.coverage * beat.ramp(0.14, 0.50)

            MiniDesktop {
                page
                sheet(covering: wipe)
            }
        }
    }

    /// Dark text on a bright white page — the glare the matte is for, and the
    /// case where covered and bare are easiest to tell apart. Every line runs
    /// the full width, so each one crosses the sheet's edge.
    private var page: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            VStack(alignment: .leading, spacing: 9) {
                DesktopTextLine(width: 92, opacity: 0.82, color: .black)

                VStack(alignment: .leading, spacing: 8) {
                    DesktopTextLine(width: 186, opacity: 0.55, color: .black)
                    DesktopTextLine(width: 168, opacity: 0.55, color: .black)
                    DesktopTextLine(width: 186, opacity: 0.55, color: .black)
                    DesktopTextLine(width: 142, opacity: 0.55, color: .black)
                }

                LinearGradient(
                    colors: [.orange, .pink, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 186, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The real overlay, clipped to the leading `fraction` of the mock screen so
    /// it reads as a sheet drawn across and left there.
    ///
    /// Carried at more than its shipping strength: a 20% matte on a 214-point
    /// desktop is invisible.
    private func sheet(covering fraction: Double) -> some View {
        PaperOverlayLayers(texture: .parchment, grainTilePoints: Self.grainTilePoints)
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
