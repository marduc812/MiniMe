//
//  PasteService.swift
//  MiniMe
//

import AppKit
import CoreGraphics

/// Writes a clipboard entry back to the system pasteboard and, when configured to,
/// returns focus to the app the user came from and synthesizes ⌘V.
@MainActor
final class PasteService {
    static let shared = PasteService()
    private init() {}

    enum PickBehavior: String, CaseIterable, Identifiable {
        case copyAndPaste
        case copyOnly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .copyAndPaste: return "Copy and paste"
            case .copyOnly:     return "Copy only"
            }
        }

        static func from(rawValue: String) -> PickBehavior {
            PickBehavior(rawValue: rawValue) ?? .copyAndPaste
        }
    }

    /// How long to wait for the target app to actually come frontmost before
    /// giving up on the paste.
    private static let activationTimeout: TimeInterval = 1.0
    /// Interval between checks for activation.
    private static let activationPollInterval: TimeInterval = 0.02
    /// Brief settle after the app is frontmost, so it has taken first responder.
    private static let firstResponderSettleDelay: TimeInterval = 0.05

    /// Writes `entry` to the general pasteboard.
    /// Returns `false` if the entry's backing blob or files no longer exist.
    @discardableResult
    func writeToPasteboard(_ entry: ClipboardEntry, store: ClipboardStore) -> Bool {
        let pasteboard = NSPasteboard.general

        switch entry.content {
        case .text(let string):
            pasteboard.clearContents()
            return pasteboard.setString(string, forType: .string)

        case .image(let fileName, _, _):
            guard let image = NSImage(contentsOf: store.blobURL(named: fileName)) else { return false }
            pasteboard.clearContents()
            return pasteboard.writeObjects([image])

        case .files(let paths):
            let urls = paths.map { URL(fileURLWithPath: $0) }
            guard !urls.isEmpty,
                  urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else { return false }
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls as [NSURL])
        }
    }

    /// Reactivates `app` and synthesizes ⌘V. Does nothing if Accessibility
    /// permission is not granted — the caller has already put the entry on the
    /// clipboard, so the user can still paste manually. No known app to return to:
    /// the content is already on the clipboard, and firing ⌘V blindly into whatever
    /// is frontmost would be worse than letting the user paste it themselves.
    func paste(into app: NSRunningApplication?) {
        // Checked without prompting: the permission is optional for the
        // clipboard, and a modal on every pick would badger a user who has
        // deliberately chosen to paste manually.
        guard TypingService.shared.isAccessibilityTrusted else { return }
        guard let app else { return }

        // The deployment target is macOS 14.6, so the no-argument activate() is
        // available unconditionally; activate(options:) is deprecated on 14+.
        app.activate()
        waitForActivation(of: app, deadline: Date().addingTimeInterval(Self.activationTimeout))
    }

    /// Polls until `app` is frontmost, then posts ⌘V. Gives up silently at the
    /// deadline — the entry is already on the clipboard, so degrading to
    /// copy-only is the safe failure, and pasting into the wrong app is not.
    private func waitForActivation(of app: NSRunningApplication, deadline: Date) {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstResponderSettleDelay) {
                Self.postCommandV()
            }
            return
        }

        guard Date() < deadline else {
            print("[PasteService] \(app.localizedName ?? "target app") did not activate in time; skipping paste")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationPollInterval) { [weak self] in
            self?.waitForActivation(of: app, deadline: deadline)
        }
    }

    private static func postCommandV() {
        let vKeyCode: CGKeyCode = 9
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
