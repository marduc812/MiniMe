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
                    Text("Countdown before typing")
                    Spacer()
                    Picker("", selection: $settings.typeItCountdownDuration) {
                        ForEach(1...10, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                }
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "speaker.wave.2.fill", color: .purple)
                    Toggle("Sound on countdown", isOn: $settings.typeItCountdownSound)
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
