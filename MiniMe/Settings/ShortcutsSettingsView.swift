//
//  ShortcutsSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Capture") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "viewfinder.circle.fill", color: .orange)
                    Text("Capture screen area")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.captureShortcut)
                }
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "clock.arrow.circlepath", color: .orange)
                    Text("Open History")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.historyShortcut)
                }
            }

            Section("Type It") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "keyboard.fill", color: .purple)
                    Text("Type It")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.typeItShortcut)
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
