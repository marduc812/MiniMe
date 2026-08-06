//
//  PaperDisplaySelectionTests.swift
//  MiniMeTests
//

import Testing
import CoreGraphics
@testable import MiniMe

/// Which attached displays the matte covers, given the ones the user switched
/// off. Kept away from `PaperOverlayManager` for the same reason
/// `PaperWindowPlan` is: the decision is the part that can be wrong.
struct PaperDisplaySelectionTests {

    private let laptop: CGDirectDisplayID = 1
    private let external: CGDirectDisplayID = 2
    private let projector: CGDirectDisplayID = 3

    @Test func withNoExclusionsEveryDisplayIsCovered() {
        let covered = PaperDisplaySelection.covered(
            attached: [laptop, external, projector],
            excluded: []
        )

        #expect(covered == [laptop, external, projector])
    }

    @Test func anExcludedDisplayIsDroppedAndTheRestAreKept() {
        let covered = PaperDisplaySelection.covered(
            attached: [laptop, external, projector],
            excluded: [external]
        )

        #expect(covered == [laptop, projector])
    }

    /// The exclusion list outlives the display it names — unplugging a monitor
    /// must not disturb the displays that are still attached.
    @Test func excludingADisplayThatIsNotAttachedChangesNothing() {
        let covered = PaperDisplaySelection.covered(
            attached: [laptop],
            excluded: [projector]
        )

        #expect(covered == [laptop])
    }

    /// Display IDs churn across reboots and dock cycles, so the stored list is
    /// what the user switched *off*. An ID nobody has an opinion about gets a
    /// matte — the same behaviour as before per-display selection existed, and
    /// the failure mode is one click rather than a tool that looks broken.
    @Test func anUnknownDisplayIsCovered() {
        let covered = PaperDisplaySelection.covered(
            attached: [laptop, projector],
            excluded: [external]
        )

        #expect(covered.contains(projector))
    }

    /// Allowed, and it means no windows. The Settings row says so rather than
    /// reporting the matte as on and covering nothing.
    @Test func excludingEveryAttachedDisplayCoversNothing() {
        let covered = PaperDisplaySelection.covered(
            attached: [laptop, external],
            excluded: [laptop, external]
        )

        #expect(covered.isEmpty)
    }

    @Test func nothingAttachedCoversNothing() {
        #expect(PaperDisplaySelection.covered(attached: [], excluded: [laptop]).isEmpty)
    }
}
