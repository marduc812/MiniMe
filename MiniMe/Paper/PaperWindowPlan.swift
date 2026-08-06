//
//  PaperWindowPlan.swift
//  MiniMe
//

import CoreGraphics

/// Which overlay windows to open and which to close, given the windows that
/// exist and the displays that are attached.
///
/// Split out of `PaperOverlayManager` because the decision is the part that can
/// be wrong — a window left behind for a detached display, or every window torn
/// down and rebuilt because a colour profile changed. Testing it there would
/// mean opening real windows in the test bundle.
struct PaperWindowPlan: Equatable {
    let add: Set<CGDirectDisplayID>
    let remove: Set<CGDirectDisplayID>

    var isEmpty: Bool { add.isEmpty && remove.isEmpty }

    /// Pass an empty `attached` set to plan a full teardown.
    static func reconciling(
        existing: Set<CGDirectDisplayID>,
        attached: Set<CGDirectDisplayID>
    ) -> PaperWindowPlan {
        PaperWindowPlan(
            add: attached.subtracting(existing),
            remove: existing.subtracting(attached)
        )
    }
}
