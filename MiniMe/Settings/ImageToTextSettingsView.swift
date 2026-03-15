//
//  ImageToTextSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ImageToTextSettingsView: View {
    @ObservedObject var settings: SettingsManager

    private let languages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("de-DE", "German"),
        ("fr-FR", "French"),
        ("es-ES", "Spanish"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean")
    ]

    private let ocrAccuracyOptions = [
        ("fast", "Fast"),
        ("accurate", "Accurate")
    ]

    var body: some View {
        Form {
            Section("Output") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "doc.on.clipboard.fill", color: .blue)
                    Toggle("Copy text to clipboard automatically", isOn: $settings.autoCopyToClipboard)
                }
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "speaker.wave.2.fill", color: .green)
                    Toggle("Play sound on capture", isOn: $settings.playSound)
                }
            }

            Section("Recognition") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "globe", color: .blue)
                    Picker("Language", selection: $settings.recognitionLanguage) {
                        ForEach(languages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                }
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "dial.medium.fill", color: .orange)
                    Picker("OCR Accuracy", selection: $settings.ocrAccuracy) {
                        ForEach(ocrAccuracyOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "text.alignleft", color: .indigo)
                    Toggle("Line-aware text ordering", isOn: $settings.lineAwareOCR)
                }
            }

        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}
