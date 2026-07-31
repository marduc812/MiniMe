//
//  SceneBeat.swift
//  MiniMe
//

import Foundation

/// Where a looping onboarding scene currently sits, as a fraction of one loop,
/// plus the two curves every scene is built from.
///
/// The scenes are driven by `TimelineView(.animation)` rather than by
/// `withAnimation`, so there is no SwiftUI animation curve to lean on — the
/// easing has to live in the math. Each element derives its own geometry from
/// the beat by carving out a window of the loop, which is what lets a scene read
/// as a list of independent parts instead of a pile of nested state.
///
/// Named `SceneBeat` rather than `ScenePhase` to stay out of the way of
/// `SwiftUI.ScenePhase`.
struct SceneBeat {
    /// Position within the loop, 0…1.
    let t: Double

    init(t: Double) {
        self.t = t
    }

    init(elapsed: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else {
            t = 0
            return
        }
        t = elapsed.truncatingRemainder(dividingBy: duration) / duration
    }

    /// Eased 0→1 across `start...end`, flat outside it.
    ///
    /// An empty window snaps from 0 to 1 rather than dividing by zero.
    func ramp(_ start: Double, _ end: Double) -> Double {
        if t <= start { return 0 }
        if t >= end { return 1 }
        return Self.smoothstep((t - start) / (end - start))
    }

    /// Eased 0→1→0, peaking at `peak` and flat outside `start...end`.
    func pulse(_ start: Double, _ peak: Double, _ end: Double) -> Double {
        if t < start || t > end { return 0 }
        return t <= peak ? ramp(start, peak) : 1 - ramp(peak, end)
    }

    private static func smoothstep(_ x: Double) -> Double {
        x * x * (3 - 2 * x)
    }
}
