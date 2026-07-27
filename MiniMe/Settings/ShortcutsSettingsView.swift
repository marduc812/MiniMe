//
//  ShortcutsSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        // Only shortcuts that actually fire are listed — a tool switched off in
        // General has no registered hotkey, so showing its row would be a lie.
        Form {
            if settings.isEnabled(.capture) {
                Section("Capture") {
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "viewfinder.circle.fill", color: .orange)
                        Text("Capture screen area")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.captureShortcut)
                    }
                }
            }

            if settings.isEnabled(.typeIt) {
                Section("Type It") {
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "keyboard.fill", color: .purple)
                        Text("Type It")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.typeItShortcut)
                    }
                }
            }

            if settings.isEnabled(.clipboard) {
                Section("Clipboard") {
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "doc.on.clipboard.fill", color: .teal)
                        Text("Open clipboard picker")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.clipboardShortcut)
                    }
                }
            }

            if settings.isEnabled(.moveMouse) {
                Section("Mouse") {
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "cursorarrow.motionlines", color: .indigo)
                        Text("Start / Stop moving mouse")
                        Spacer()
                        ShortcutRecorderButton(shortcut: $settings.moveMouseShortcut)
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
        .padding(.top, 4)
    }
}
