//
//  MiniDesktop.swift
//  MiniMe
//

import SwiftUI

/// The mock screen every onboarding scene is staged inside.
///
/// Children position themselves with `.offset(x:y:)` from the top-left, which
/// keeps each scene readable as a flat list of independently-timed parts.
struct MiniDesktop<Content: View>: View {
    static var size: CGSize { CGSize(width: 214, height: 134) }

    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            content
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(red: 0.16, green: 0.17, blue: 0.24))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

/// A stand-in for a line of text on the mock screen.
struct DesktopTextLine: View {
    var width: CGFloat
    var opacity: Double = 0.42
    var color: Color = .white

    var body: some View {
        Capsule()
            .fill(color.opacity(opacity))
            .frame(width: width, height: 5)
    }
}

/// Drives a looping scene, and collapses it to a single still frame when the
/// user has asked for reduced motion.
///
/// Onboarding is a screen made almost entirely of movement, so honouring
/// Reduce Motion here is not decorative — without it the flow is unusable for
/// anyone who set it.
struct SceneStage<Content: View>: View {
    /// Length of one loop, in seconds.
    let duration: TimeInterval
    /// The point in the loop to freeze at under Reduce Motion. Pick the frame
    /// that shows the outcome — the text already captured, the entry already
    /// pasted — since a still of the setup phase explains nothing.
    let resting: Double
    @ViewBuilder var content: (SceneBeat) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(SceneBeat(t: resting))
        } else {
            TimelineView(.animation) { timeline in
                content(
                    SceneBeat(
                        elapsed: timeline.date.timeIntervalSinceReferenceDate,
                        duration: duration
                    )
                )
            }
        }
    }
}

extension Tool {
    /// The looping animation shown above this tool's slide.
    @ViewBuilder var onboardingScene: some View {
        switch self {
        case .capture:      CaptureScene()
        case .typeIt:       TypeItScene()
        case .clipboard:    ClipboardScene()
        case .moveMouse:    MoveMouseScene()
        case .preventSleep: PreventSleepScene()
        }
    }

    /// The one-sentence statement of purpose shown under the animation.
    var onboardingPurpose: String {
        switch self {
        case .capture:
            return "Pull text out of anything on screen — a screenshot, a video, a window that won't let you select."
        case .typeIt:
            return "Types your clipboard out key by key, for fields that refuse a paste."
        case .clipboard:
            return "Keeps everything you copy, so you can go back and grab it again."
        case .moveMouse:
            return "Nudges the pointer now and then so your Mac never looks away."
        case .preventSleep:
            return "Holds the display awake for as long as you pick."
        }
    }
}
