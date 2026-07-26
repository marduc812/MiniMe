//
//  ActiveScreenResolver.swift
//  MiniMe
//

import AppKit

/// Resolves which display the user is currently working on, and places a rect
/// on it.
///
/// The obvious `NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
/// ?? NSScreen.main` fails in two reachable cases:
///
/// 1. `CGRect.contains` excludes the `maxX`/`maxY` edges, so a cursor pinned to
///    the top or right edge of a display matches no frame.
/// 2. Displays of differing sizes arranged with an offset leave coordinate space
///    that belongs to no screen.
///
/// Both fall through to `NSScreen.main`, which means "the screen with the key
/// window" — meaningless for a menu-bar-only app like MiniMe, and frequently the
/// wrong display. Falling back to the *nearest* screen instead always lands where
/// the cursor is.
enum ActiveScreenResolver {

    /// Pure core: index of the screen containing `mouseLocation`, else the index
    /// of the nearest screen by squared distance. `nil` only when `frames` is empty.
    static func screenIndex(mouseLocation: CGPoint, frames: [CGRect]) -> Int? {
        guard !frames.isEmpty else { return nil }

        if let index = frames.firstIndex(where: { $0.contains(mouseLocation) }) {
            return index
        }

        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, frame) in frames.enumerated() {
            // Distance from the point to the rect, zero along any axis where the
            // point already falls within the rect's span.
            let dx = max(frame.minX - mouseLocation.x, 0, mouseLocation.x - frame.maxX)
            let dy = max(frame.minY - mouseLocation.y, 0, mouseLocation.y - frame.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// The screen the user is currently on, or `nil` if there are no screens.
    static func activeScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = screenIndex(
            mouseLocation: NSEvent.mouseLocation,
            frames: screens.map(\.frame)
        ) else { return nil }
        return screens[index]
    }

    /// A rect of `size` centered in `visibleFrame`, shrunk and clamped so it is
    /// always fully on-screen and clear of the menu bar and Dock.
    static func centeredRect(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)

        let x = min(max(visibleFrame.midX - width / 2, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(visibleFrame.midY - height / 2, visibleFrame.minY), visibleFrame.maxY - height)

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
