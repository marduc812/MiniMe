//
//  AboutIconEyeGeometry.swift
//  MiniMe
//

import CoreGraphics

/// Pure geometry behind the About tab's cursor-tracking eyes, kept separate from
/// the view so the direction maths can be tested without a running window.
enum AboutIconEyeGeometry {

    /// Distance at which the pupils reach their full deflection. Closer than this
    /// they move proportionally, so a cursor drifting near the icon reads as a
    /// glance instead of snapping straight to the edge of the eye.
    static let falloffRadius: CGFloat = 120

    /// Offset to apply to both pupils so they aim at `pointer`.
    ///
    /// - Parameters:
    ///   - pointer: Cursor position, or `nil` when the cursor has left the pane.
    ///   - iconCenter: Icon centre in the same coordinate space as `pointer`.
    ///   - maxShift: Largest distance a pupil may travel from its resting spot.
    static func pupilOffset(
        pointer: CGPoint?,
        iconCenter: CGPoint,
        maxShift: CGFloat,
        falloffRadius: CGFloat = falloffRadius
    ) -> CGSize {
        guard let pointer else { return .zero }

        let dx = pointer.x - iconCenter.x
        let dy = pointer.y - iconCenter.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0 else { return .zero }

        // Normalising before scaling keeps a diagonal pointer inside the eye;
        // clamping each axis on its own would let the pupil out by a factor of √2.
        let reach = maxShift * min(distance / falloffRadius, 1)
        return CGSize(width: dx / distance * reach, height: dy / distance * reach)
    }
}
