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

    /// Delay between reactivating the previous app and posting ⌘V. Without it the
    /// keystroke can arrive before the app has taken first responder back.
    private static let activationSettleDelay: TimeInterval = 0.15

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
    /// clipboard, so the user can still paste manually.
    func paste(into app: NSRunningApplication?) {
        guard TypingService.shared.ensureAccessibilityPermission() else { return }

        activate(app)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationSettleDelay) {
            Self.postCommandV()
        }
    }

    private func activate(_ app: NSRunningApplication?) {
        // The deployment target is macOS 14.6, so the no-argument activate() is
        // available unconditionally; activate(options:) is deprecated on 14+.
        app?.activate()
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
