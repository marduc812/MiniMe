//
//  PaperWindowPlanTests.swift
//  MiniMeTests
//

import Testing
import CoreGraphics
@testable import MiniMe

/// Reconciling overlay windows against the attached displays. Kept away from
/// `PaperOverlayManager` so the decision can be tested without opening windows.
struct PaperWindowPlanTests {

    private let laptop: CGDirectDisplayID = 1
    private let external: CGDirectDisplayID = 2
    private let projector: CGDirectDisplayID = 3

    @Test func aFirstActivationAddsAWindowPerDisplay() {
        let plan = PaperWindowPlan.reconciling(existing: [], attached: [laptop, external])

        #expect(plan.add == [laptop, external])
        #expect(plan.remove.isEmpty)
    }

    @Test func anAttachedDisplayGetsAWindow() {
        let plan = PaperWindowPlan.reconciling(existing: [laptop], attached: [laptop, projector])

        #expect(plan.add == [projector])
        #expect(plan.remove.isEmpty)
    }

    /// A window for a display that is gone would otherwise linger, holding its
    /// backing store and reappearing on the wrong screen if the ID is reused.
    @Test func aDetachedDisplayLosesItsWindow() {
        let plan = PaperWindowPlan.reconciling(existing: [laptop, external], attached: [laptop])

        #expect(plan.add.isEmpty)
        #expect(plan.remove == [external])
    }

    @Test func swappingOneMonitorForAnotherAddsAndRemoves() {
        let plan = PaperWindowPlan.reconciling(existing: [laptop, external], attached: [laptop, projector])

        #expect(plan.add == [projector])
        #expect(plan.remove == [external])
    }

    /// Screen-parameter notifications fire for things that are none of our
    /// business — a resolution change, a colour profile switch. Rebuilding every
    /// window on those would flicker the matte for no reason.
    @Test func anUnchangedScreenListIsANoOp() {
        let plan = PaperWindowPlan.reconciling(existing: [laptop, external], attached: [laptop, external])

        #expect(plan.isEmpty)
    }

    @Test func deactivatingRemovesEveryWindow() {
        let plan = PaperWindowPlan.reconciling(existing: [laptop, external], attached: [])

        #expect(plan.add.isEmpty)
        #expect(plan.remove == [laptop, external])
    }
}
