//
//  PaperOverlayWindow.swift
//  MiniMe
//

import AppKit
import SwiftUI

/// A full-screen matte over one display.
///
/// Follows `SelectionWindow`'s shape — borderless, screen-sized, joins every
/// Space — but is entirely inert: it takes no clicks, no keys and no focus, and
/// never activates the app. The only thing that changes after it opens is its
/// texture and its `alphaValue`.
final class PaperOverlayWindow: NSWindow {
    let displayID: CGDirectDisplayID

    private let host: NSHostingView<PaperOverlayLayers>

    init(screen: NSScreen, texture: PaperTexture, alpha: CGFloat) {
        displayID = screen.displayID
        host = NSHostingView(rootView: PaperOverlayLayers(texture: texture))

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Over the menu bar and the Dock, and one below `SelectionWindow`, so a
        // capture selection is never drawn underneath the matte.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        alphaValue = alpha

        // Clicks, keys and scrolls all pass straight through to whatever is
        // underneath — the matte is a surface, not a window you interact with.
        ignoresMouseEvents = true

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        // Keeps the matte out of screenshots and screen recordings — including
        // MiniMe's own Capture, which has to OCR the real screen rather than a
        // grainy one. `ScreenCaptureManager` excludes these windows explicitly
        // as well; this is the half that covers every other capturing app.
        sharingType = .none

        contentView = host
        setFrame(screen.frame, display: false)
    }

    /// Never becomes key or main, so it can't steal focus from the app the user
    /// is actually working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func apply(texture: PaperTexture, alpha: CGFloat) {
        host.rootView = PaperOverlayLayers(texture: texture)
        alphaValue = alpha
    }

    /// Re-follows its screen after a resolution or arrangement change.
    func matchFrame(of screen: NSScreen) {
        setFrame(screen.frame, display: true)
    }
}
