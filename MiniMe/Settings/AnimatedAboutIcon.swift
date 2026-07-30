//
//  AnimatedAboutIcon.swift
//  MiniMe
//

import SwiftUI

/// The app mark on the About tab, with eyes that follow the cursor, blink now and
/// then, and a slow drift into the app's purple and back.
///
/// The bundled MenuBarIcon is a single flat path, so its eyes cannot be moved on
/// their own. This view stacks a copy with the eyes removed
/// (`MenuBarIconEyeless`) under two circles it draws itself, using the same
/// coordinates the original SVG uses on its 256pt canvas.
struct AnimatedAboutIcon: View {
    /// Cursor position in `space`, or `nil` once the cursor leaves the pane.
    let pointer: CGPoint?
    /// Coordinate space `pointer` is measured in; the icon locates itself in the
    /// same space so it can work out which way to look.
    let space: String
    var size: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var eyesClosed = false
    @State private var purpleAmount: Double = 0

    // Straight from MenuBarIcon.svg.
    private let canvas: CGFloat = 256
    private let leftEyeCenter = CGPoint(x: 92, y: 140)
    private let rightEyeCenter = CGPoint(x: 164, y: 140)
    private let eyeRadius: CGFloat = 12

    private var scale: CGFloat { size / canvas }

    /// Sampled from the app icon artwork: violet at the top, indigo at the base.
    private let brandGradient = LinearGradient(
        colors: [
            Color(red: 171 / 255, green: 95 / 255, blue: 251 / 255),
            Color(red: 77 / 255, green: 59 / 255, blue: 209 / 255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(space))
            let offset = AboutIconEyeGeometry.pupilOffset(
                pointer: reduceMotion ? nil : pointer,
                iconCenter: CGPoint(x: frame.midX, y: frame.midY),
                maxShift: size * 0.035
            )

            ZStack {
                face(offset, tint: AnyShapeStyle(.primary))
                face(offset, tint: AnyShapeStyle(brandGradient))
                    .opacity(purpleAmount)
            }
            .animation(.interpolatingSpring(stiffness: 170, damping: 14), value: pointer)
        }
        .frame(width: size, height: size)
        .onAppear(perform: startBreathing)
        .task(blinkForever)
    }

    private func face(_ pupilOffset: CGSize, tint: AnyShapeStyle) -> some View {
        ZStack {
            Image("MenuBarIconEyeless")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()

            eye(at: leftEyeCenter, pupilOffset: pupilOffset)
            eye(at: rightEyeCenter, pupilOffset: pupilOffset)
        }
        .frame(width: size, height: size)
        .foregroundStyle(tint)
    }

    private func eye(at center: CGPoint, pupilOffset: CGSize) -> some View {
        // Offsets are measured from the icon's middle so the eyes ride along with
        // whatever frame the stack ends up at.
        let restX = (center.x - canvas / 2) * scale
        let restY = (center.y - canvas / 2) * scale

        return Circle()
            .frame(width: eyeRadius * 2 * scale, height: eyeRadius * 2 * scale)
            .scaleEffect(y: eyesClosed ? 0.12 : 1)
            .offset(x: restX + pupilOffset.width, y: restY + pupilOffset.height)
    }

    private func startBreathing() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            purpleAmount = 1
        }
    }

    @Sendable private func blinkForever() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(.random(in: 3.5...6.5)))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.07)) { eyesClosed = true }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.1)) { eyesClosed = false }
        }
    }
}
