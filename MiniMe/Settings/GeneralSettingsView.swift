//
//  GeneralSettingsView.swift
//  MiniMe
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    /// With the icon hidden, a hotkey is the only way back in — so name one
    /// that actually works. Capture is the natural suggestion, but it can be
    /// switched off, and every hotkey tool can be off at once.
    private var hiddenIconHint: String {
        let candidates: [Tool] = [.capture, .clipboard, .typeIt]
        guard let tool = candidates.first(where: { settings.isEnabled($0) }) else {
            return "No tool with a shortcut is switched on. Re-open MiniMe from Finder to change this."
        }
        let shortcut: CustomShortcut
        switch tool {
        case .clipboard: shortcut = settings.clipboardShortcut
        case .typeIt:    shortcut = settings.typeItShortcut
        default:         shortcut = settings.captureShortcut
        }
        return "Use \(shortcut.displayString) (\(tool.title)) to interact with MiniMe."
    }

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
                            Text(hiddenIconHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Tools") {
                ForEach(Tool.allCases) { tool in
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: tool.icon, color: .blue)
                        Toggle(tool.title, isOn: Binding(
                            get: { settings.isEnabled(tool) },
                            set: { settings.setEnabled(tool, $0) }
                        ))
                        .accessibilityIdentifier("tool-toggle-\(tool.rawValue)")
                    }
                }

                Text("Turning a tool off hides it from the menu bar and disables its shortcut.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
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
