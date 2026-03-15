//
//  TypeItSettingsView.swift
//  MiniMe
//

import SwiftUI

struct TypeItSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Behaviour") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "timer", color: .purple)
                    Stepper(
                        value: $settings.typeItCountdownDuration,
                        in: 1...10
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Countdown before typing")
                            Text("\(settings.typeItCountdownDuration) second\(settings.typeItCountdownDuration == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Text("Type It reads your selected text and retypes it character by character after the countdown, so you can switch to the target window in time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}
