//
//  TypingService.swift
//  MiniMe
//

import AppKit
import ApplicationServices
import Combine

class TypingService: ObservableObject {
    static let shared = TypingService()
    private init() {}

    @Published var countdown: Int? = nil

    func typeText(_ text: String, closeAction: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "MiniMe needs Accessibility permission to simulate typing. Please grant it in System Settings → Privacy & Security → Accessibility."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        closeAction?()

        let stored = UserDefaults.standard.integer(forKey: "typeItCountdownDuration")
        let duration = (1...10).contains(stored) ? stored : 5

        countdown = duration
        for i in 1..<duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                self.countdown = duration - i
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            self.countdown = nil
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Double(duration)) {
            self.performTyping(text)
        }
    }

    func typeFromSelection() {
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "MiniMe needs Accessibility permission to simulate typing. Please grant it in System Settings → Privacy & Security → Accessibility."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        // Save current clipboard, simulate Cmd+C, read selection, restore clipboard
        let previousContents = NSPasteboard.general.string(forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let selected = NSPasteboard.general.string(forType: .string) ?? ""

            // Restore previous clipboard
            NSPasteboard.general.clearContents()
            if let prev = previousContents {
                NSPasteboard.general.setString(prev, forType: .string)
            }

            guard !selected.isEmpty else { return }
            self.typeText(selected)
        }
    }

    private func performTyping(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            var char = UniChar(scalar.value & 0xFFFF)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
