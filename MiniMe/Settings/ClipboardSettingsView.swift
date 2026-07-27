//
//  ClipboardSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var store: ClipboardStore

    @State private var showingClearConfirmation = false

    private let tint = Color.teal

    private static let limitOptions = [50, 100, 200, 500]

    var body: some View {
        Form {
            Section("History") {
                SettingsRow(icon: "tray.full.fill", tint: tint) {
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
                SettingsRow(icon: "arrow.down.doc.fill", tint: tint) {
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

                SettingsRow(icon: "command.square.fill", tint: tint) {
                    Text("Open clipboard picker")
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.clipboardShortcut)
                }
            }

            Section("Capture") {
                SettingsRow(icon: "photo.fill", tint: tint) {
                    Toggle("Capture images and files", isOn: $settings.clipboardCaptureImagesAndFiles)
                }

                SettingsRow(icon: "lock.fill", tint: tint) {
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
    }
}
