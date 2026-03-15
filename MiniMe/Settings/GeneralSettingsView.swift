//
//  GeneralSettingsView.swift
//  MiniMe
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some View {
        Form {
            Section("App") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "arrow.up.circle.fill", color: .blue)
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                }
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "menubar.rectangle", color: .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                        if !showMenuBarIcon {
                            Text("Use your capture hotkey to interact with MiniMe.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Reset All Shortcuts to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}
