//
//  ClipboardSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var store: ClipboardStore

    @State private var showingClearConfirmation = false

    private static let limitOptions = [50, 100, 200, 500]

    var body: some View {
        Form {
            Section("History") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "tray.full.fill", color: .teal)
                    Text("Keep at most")
                    Spacer()
                    Picker("", selection: $settings.clipboardMaxEntries) {
                        ForEach(Self.limitOptions, id: \.self) { limit in
                            Text("\(limit) items").tag(limit)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
            }

            Section("Behavior") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "arrow.down.doc.fill", color: .indigo)
                    Text("On selecting an item")
                    Spacer()
                    Picker("", selection: $settings.clipboardPickBehavior) {
                        ForEach(PasteService.PickBehavior.allCases) { behavior in
                            Text(behavior.label).tag(behavior.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "command.square.fill", color: .indigo)
                    Text("Open clipboard picker")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.clipboardShortcut)
                }
            }

            Section("Capture") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "photo.fill", color: .orange)
                    Toggle("Capture images and files", isOn: $settings.clipboardCaptureImagesAndFiles)
                }

                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "lock.fill", color: .orange)
                    Toggle("Ignore password-manager clipboard", isOn: $settings.clipboardIgnoreConcealed)
                }

                Text("Apps such as password managers mark copied secrets as concealed. MiniMe never stores those while this is on.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Section {
                Button("Clear Clipboard History") {
                    showingClearConfirmation = true
                }
                .foregroundStyle(.red)
                .confirmationDialog(
                    "Clear all \(store.entries.count) clipboard items?",
                    isPresented: $showingClearConfirmation
                ) {
                    Button("Clear History", role: .destructive) { store.clearAll() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cannot be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}
