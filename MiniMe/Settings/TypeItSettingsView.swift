//
//  TypeItSettingsView.swift
//  MiniMe
//

import SwiftUI

struct TypeItSettingsView: View {
    @ObservedObject var settings: SettingsManager

    private let tint = Color.purple

    var body: some View {
        Form {
            Section("Behaviour") {
                SettingsRow(icon: "timer", tint: tint) {
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
                SettingsRow(icon: "speaker.wave.2.fill", tint: tint) {
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
    }
}
