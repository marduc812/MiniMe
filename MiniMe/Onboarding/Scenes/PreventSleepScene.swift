//
//  PreventSleepScene.swift
//  MiniMe
//

import SwiftUI

/// The display fades toward black, a crescent swells and bursts, and the screen
/// snaps back to full brightness with a countdown running.
struct PreventSleepScene: View {
    var body: some View {
        SceneStage(duration: 5.0, resting: 0.80) { beat in
            let dim = 0.72 * beat.ramp(0.02, 0.34) * (1 - beat.ramp(0.46, 0.58))
            let moon = beat.ramp(0.36, 0.46) * (1 - beat.ramp(0.56, 0.64))
            let moonScale = 0.6 + 0.4 * beat.ramp(0.36, 0.46) + 0.5 * beat.ramp(0.46, 0.64)
            let timer = beat.ramp(0.56, 0.66) * (1 - beat.ramp(0.92, 1.0))

            MiniDesktop {
                DesktopTextLine(width: 96).offset(x: 22, y: 30)
                DesktopTextLine(width: 70).offset(x: 22, y: 42)
                DesktopTextLine(width: 84).offset(x: 22, y: 54)

                Color.black.opacity(dim)

                Crescent()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .scaleEffect(moonScale)
                    .opacity(moon)
                    .offset(x: 91, y: 51)

                Text("2:00:00")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        Capsule().strokeBorder(Color.accentColor, lineWidth: 1)
                    )
                    .opacity(timer)
                    .offset(x: 142, y: 14)
            }
        }
    }
}

/// A moon, cut as one circle minus another offset circle.
private struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        let full = Path(ellipseIn: rect)
        let bite = Path(ellipseIn: rect.offsetBy(dx: rect.width * 0.28, dy: -rect.height * 0.06))
        return full.subtracting(bite)
    }
}
