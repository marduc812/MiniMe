//
//  ImageToTextSettingsView.swift
//  MiniMe
//

import SwiftUI

struct ImageToTextSettingsView: View {
    @ObservedObject var settings: SettingsManager

    private let tint = Color.orange

    private let languages = [
        (OCROptions.automaticLanguage, "Automatic (detect)"),
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
                SettingsRow(icon: "speaker.wave.2.fill", tint: tint) {
                    Toggle("Play sound on capture", isOn: $settings.playSound)
                }
            }

            Section("Recognition") {
                SettingsRow(icon: "globe", tint: tint) {
                    Picker("Language", selection: $settings.recognitionLanguage) {
                        ForEach(languages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                }
                SettingsRow(icon: "dial.medium.fill", tint: tint) {
                    Picker("OCR Accuracy", selection: $settings.ocrAccuracy) {
                        ForEach(ocrAccuracyOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                SettingsRow(icon: "text.alignleft", tint: tint) {
                    Toggle("Line-aware text ordering", isOn: $settings.lineAwareOCR)
                }
                SettingsRow(icon: "textformat.abc.dottedunderline", tint: tint) {
                    Toggle("Language correction", isOn: $settings.useLanguageCorrection)
                }
                Text("Language correction fixes natural-language typos but can alter code, URLs, and IDs. Leave off for technical text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
    }
}
