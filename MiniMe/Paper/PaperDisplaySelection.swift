//
//  PaperDisplaySelection.swift
//  MiniMe
//

import CoreGraphics

/// Which of the attached displays the matte covers.
///
/// Split out of `PaperOverlayManager` for the same reason `PaperWindowPlan` is:
/// the decision is the part that can be wrong, and testing it there would mean
/// attaching real monitors to the test bundle.
///
/// The stored side of this is a list of displays the user switched **off**, not
/// the ones they switched on. Display IDs churn — across reboots, dock cycles
/// and GPU switches — and the two lists fail in opposite directions when they
/// do. An exclusion list that no longer matches anything covers every display:
/// the user sees a matte they did not ask for and clicks once. An inclusion
/// list that no longer matches anything covers nothing, which is a tool that
/// silently does nothing with no indication why.
///
/// It also gives a newly attached display the right default: unknown means not
/// excluded, means covered — what Paper did before this existed.
enum PaperDisplaySelection {
    static func covered(
        attached: Set<CGDirectDisplayID>,
        excluded: Set<CGDirectDisplayID>
    ) -> Set<CGDirectDisplayID> {
        attached.subtracting(excluded)
    }
}

/// One attached display, as the Settings list shows it.
struct PaperDisplay: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    /// `NSScreen.localizedName` — "Built-in Retina Display", "DELL U2720Q".
    let name: String
    let isCovered: Bool
}
