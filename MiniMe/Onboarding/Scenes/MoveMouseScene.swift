//
//  MoveMouseScene.swift
//  MiniMe
//

import SwiftUI

/// The screen starts to dim and a "zZ" fades in — then the pointer twitches on
/// its own and the dim snaps away.
struct MoveMouseScene: View {
    var body: some View {
        SceneStage(duration: 4.5, resting: 0.74) { beat in
            let dim = 0.42 * beat.ramp(0.42, 0.60) * (1 - beat.ramp(0.60, 0.74))
            let sleepy = 0.55 * beat.ramp(0.42, 0.56) * (1 - beat.ramp(0.56, 0.70))
            let ripple = beat.ramp(0.64, 0.70) * (1 - beat.ramp(0.70, 0.92))

            // Four nudges, each leg expressed as a delta from the one before so
            // the path closes back on its starting point.
            let x = 26 * beat.ramp(0.62, 0.70)
                - 14 * beat.ramp(0.70, 0.78)
                + 22 * beat.ramp(0.78, 0.86)
                - 34 * beat.ramp(0.86, 1.0)
            let y = -14 * beat.ramp(0.62, 0.70)
                + 24 * beat.ramp(0.70, 0.78)
                - 6 * beat.ramp(0.78, 0.86)
                - 4 * beat.ramp(0.86, 1.0)

            MiniDesktop {
                DesktopTextLine(width: 96).offset(x: 22, y: 26)
                DesktopTextLine(width: 64).offset(x: 22, y: 38)

                Color.black.opacity(dim)

                Text("z")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(sleepy)
                    .offset(x: 178, y: 20 - 3 * beat.ramp(0.42, 0.56) - 7 * beat.ramp(0.56, 0.70))

                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1 + 4 * beat.ramp(0.64, 0.92))
                    .opacity(ripple)
                    .offset(x: 72 + x, y: 72 + y)

                MousePointer()
                    .fill(.white)
                    .frame(width: 14, height: 18)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .offset(x: 70 + x, y: 70 + y)
            }
        }
    }
}

/// The macOS arrow cursor, drawn rather than screenshotted so it scales cleanly.
private struct MousePointer: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width / 14
        let h = rect.height / 18
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 14 * h))
        path.addLine(to: CGPoint(x: 4 * w, y: 10.5 * h))
        path.addLine(to: CGPoint(x: 6.5 * w, y: 16 * h))
        path.addLine(to: CGPoint(x: 9 * w, y: 15 * h))
        path.addLine(to: CGPoint(x: 6.5 * w, y: 9.5 * h))
        path.addLine(to: CGPoint(x: 11 * w, y: 9.5 * h))
        path.closeSubpath()
        return path
    }
}
