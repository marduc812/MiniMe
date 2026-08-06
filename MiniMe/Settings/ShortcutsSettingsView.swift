//
//  ShortcutsSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: SettingsManager

    private let tint = Color.green

    var body: some View {
        // Only shortcuts that actually fire are listed — a tool switched off in
        // General has no registered hotkey, so showing its row would be a lie.
        Form {
            if settings.isEnabled(.capture) {
                Section("Capture") {
                    SettingsRow(icon: "viewfinder.circle.fill", tint: tint) {
                        Text("Capture screen area")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.captureShortcut)
                    }
                }
            }

            if settings.isEnabled(.typeIt) {
                Section("Type It") {
                    SettingsRow(icon: "keyboard.fill", tint: tint) {
                        Text("Type It")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.typeItShortcut)
                    }
                }
            }

            if settings.isEnabled(.clipboard) {
                Section("Clipboard") {
                    SettingsRow(icon: "doc.on.clipboard.fill", tint: tint) {
                        Text("Open clipboard picker")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.clipboardShortcut)
                    }
                }
            }

            if settings.isEnabled(.moveMouse) {
                Section("Mouse") {
                    SettingsRow(icon: "cursorarrow.motionlines", tint: tint) {
                        Text("Start / Stop moving mouse")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.moveMouseShortcut)
                    }
                }
            }

            if settings.isEnabled(.paper) {
                Section("Paper") {
                    SettingsRow(icon: "camera.filters", tint: tint) {
                        Text("Turn the paper matte on / off")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.paperShortcut)
                    }
                }
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}
