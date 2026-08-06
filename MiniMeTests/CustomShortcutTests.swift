//
//  CustomShortcutTests.swift
//  MiniMeTests
//

import Testing
import AppKit
@testable import MiniMe

struct CustomShortcutTests {

    @Test func defaultCaptureShortcutIsCommandShift2() {
        let shortcut = CustomShortcut.defaultCapture

        // keyCode 19 = '2'
        #expect(shortcut.keyCode == 19)
        // Command + Shift modifiers
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
        #expect(flags.contains(.command))
        #expect(flags.contains(.shift))
    }

    @Test func displayStringShowsModifiersAndKey() {
        let shortcut = CustomShortcut.defaultCapture
        let display = shortcut.displayString

        #expect(display.contains("⌘")) // Command
        #expect(display.contains("⇧")) // Shift
        #expect(display.contains("2")) // keyCode 19
    }

    @Test func displayStringShowsControlModifier() {
        let controlModifier = NSEvent.ModifierFlags.control.rawValue
        let shortcut = CustomShortcut(keyCode: 0, modifiers: controlModifier) // Ctrl+A

        #expect(shortcut.displayString.contains("⌃"))
    }

    @Test func displayStringShowsOptionModifier() {
        let optionModifier = NSEvent.ModifierFlags.option.rawValue
        let shortcut = CustomShortcut(keyCode: 0, modifiers: optionModifier) // Opt+A

        #expect(shortcut.displayString.contains("⌥"))
    }

    @Test func matchesReturnsTrueForMatchingInput() {
        let shortcut = CustomShortcut.defaultCapture

        let result = shortcut.matches(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)

        #expect(result == true)
    }

    @Test func matchesReturnsFalseForDifferentKeyCode() {
        let shortcut = CustomShortcut.defaultCapture

        let result = shortcut.matches(keyCode: 99, modifiers: shortcut.modifiers)

        #expect(result == false)
    }

    @Test func matchesReturnsFalseForDifferentModifiers() {
        let shortcut = CustomShortcut.defaultCapture

        let result = shortcut.matches(keyCode: shortcut.keyCode, modifiers: 0)

        #expect(result == false)
    }

    @Test func shortcutIsCodable() throws {
        let original = CustomShortcut(keyCode: 12, modifiers: 1179648)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomShortcut.self, from: data)

        #expect(decoded.keyCode == original.keyCode)
        #expect(decoded.modifiers == original.modifiers)
    }

    @Test func shortcutEquality() {
        let shortcut1 = CustomShortcut(keyCode: 8, modifiers: 1179648)
        let shortcut2 = CustomShortcut(keyCode: 8, modifiers: 1179648)
        let shortcut3 = CustomShortcut(keyCode: 4, modifiers: 1179648)

        #expect(shortcut1 == shortcut2)
        #expect(shortcut1 != shortcut3)
    }

    @Test func keyboardShortcutConversion() {
        let shortcut = CustomShortcut.defaultCapture

        let keyboardShortcut = shortcut.keyboardShortcut

        #expect(keyboardShortcut != nil)
    }

    @Test func specialKeysHaveDisplayStrings() {
        // Test some special keys
        let escapeShortcut = CustomShortcut(keyCode: 53, modifiers: 0)
        #expect(escapeShortcut.displayString.contains("ESC"))

        let returnShortcut = CustomShortcut(keyCode: 36, modifiers: 0)
        #expect(returnShortcut.displayString.contains("↩"))

        let spaceShortcut = CustomShortcut(keyCode: 49, modifiers: 0)
        #expect(spaceShortcut.displayString.contains("Space"))
    }

    @Test func defaultClipboardShortcutIsOptionC() {
        let shortcut = CustomShortcut.defaultClipboard
        #expect(shortcut.keyCode == 8)
        #expect(shortcut.displayString == "⌥C")
    }

    @Test func defaultClipboardMatchesAnOptionCEvent() {
        let optionOnly = NSEvent.ModifierFlags.option.rawValue
        #expect(CustomShortcut.defaultClipboard.matches(keyCode: 8, modifiers: optionOnly))
        #expect(!CustomShortcut.defaultClipboard.matches(keyCode: 8, modifiers: 0))
    }

    @Test func shortcutSetHoldsEveryShortcut() {
        let set = ShortcutSet(
            capture: .defaultCapture,
            typeIt: .defaultTypeIt,
            moveMouse: .defaultMoveMouse,
            clipboard: .defaultClipboard,
            paper: .defaultPaper
        )
        #expect(set.clipboard == .defaultClipboard)
        #expect(set.paper == .defaultPaper)
        #expect(set == ShortcutSet(
            capture: .defaultCapture,
            typeIt: .defaultTypeIt,
            moveMouse: .defaultMoveMouse,
            clipboard: .defaultClipboard,
            paper: .defaultPaper
        ))
    }

    @Test func defaultPaperMatchesACommandShiftPEvent() {
        let commandShift = NSEvent.ModifierFlags([.command, .shift]).rawValue
        #expect(CustomShortcut.defaultPaper.matches(keyCode: 35, modifiers: commandShift))
        #expect(!CustomShortcut.defaultPaper.matches(keyCode: 35, modifiers: 0))
    }

    /// Two tools answering the same combination means one of them never fires —
    /// `RegisterEventHotKey` hands the key to whoever asked first.
    @Test func theDefaultShortcutsAreAllDistinct() {
        let defaults: [CustomShortcut] = [
            .defaultCapture, .defaultTypeIt, .defaultMoveMouse, .defaultClipboard, .defaultPaper
        ]
        for (index, shortcut) in defaults.enumerated() {
            for other in defaults[(index + 1)...] {
                #expect(!shortcut.matches(keyCode: other.keyCode, modifiers: other.modifiers))
            }
        }
    }
}
