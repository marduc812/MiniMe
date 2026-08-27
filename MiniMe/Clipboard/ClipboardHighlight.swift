//
//  ClipboardHighlight.swift
//  MiniMe
//

import Foundation

/// Which row of the clipboard picker is the active one — highlighted in the
/// list and shown in the detail pane — as the pointer and the arrow keys argue
/// over it.
///
/// The pointer normally wins: pointing at a row is a direct statement about
/// what you want to look at, and the hover is sticky so walking the cursor out
/// to the Copy button does not snap the preview away. The keyboard takes the
/// highlight back when you use it, and keeps it until the pointer genuinely
/// moves — which is the whole reason this is a type and not two `@State`
/// properties. Arrowing down the list scrolls it, scrolling slides rows under a
/// cursor that never moved, and AppKit reports that as a hover; honouring it
/// would drag the highlight back to whatever the cursor was parked on.
struct ClipboardHighlight: Equatable {
    private(set) var selectedID: UUID?
    private(set) var hoveredID: UUID?

    /// Where the pointer was resting when the keyboard last took over. While it
    /// is set, a hover reported from that exact spot is the list moving, not the
    /// user, and is ignored.
    private var pointerAtKeyboardTakeover: CGPoint?

    init(selectedID: UUID? = nil) {
        self.selectedID = selectedID
    }

    /// The active entry: the hovered row when the pointer owns the highlight,
    /// otherwise the keyboard selection, otherwise the top of the list.
    ///
    /// Takes the visible entries rather than filtering the history again — it is
    /// consulted once per draw and once per keystroke.
    func activeEntry(in visible: [ClipboardEntry]) -> ClipboardEntry? {
        if let hoveredID, let entry = visible.first(where: { $0.id == hoveredID }) {
            return entry
        }
        if let selectedID, let entry = visible.first(where: { $0.id == selectedID }) {
            return entry
        }
        return visible.first
    }

    /// A row reporting the pointer over it, with the pointer's screen position
    /// so a hover the list caused itself can be told apart from a real one.
    mutating func pointerEntered(_ id: UUID, at pointer: CGPoint) {
        guard pointerAtKeyboardTakeover != pointer else { return }
        pointerAtKeyboardTakeover = nil
        hoveredID = id
    }

    /// The arrow keys moving the highlight, which drops any hover until the
    /// pointer moves away from `pointer`.
    mutating func keyboardSelected(_ id: UUID, at pointer: CGPoint) {
        selectedID = id
        hoveredID = nil
        pointerAtKeyboardTakeover = pointer
    }

    /// Puts the highlight back on a known row and hands the pointer its say
    /// again: used when the list itself changes out from under both of them —
    /// the picker opening, the search text changing, a row being deleted.
    mutating func reset(to id: UUID?) {
        selectedID = id
        hoveredID = nil
        pointerAtKeyboardTakeover = nil
    }

    /// Drops the hover if it is on `id`, for a row that is about to disappear.
    mutating func forgetHover(of id: UUID) {
        if hoveredID == id { hoveredID = nil }
    }
}
