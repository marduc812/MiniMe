//
//  PaperSettingsView.swift
//  MiniMe
//

import SwiftUI

struct PaperSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var paper = PaperOverlayManager.shared

    private let tint = Color.brown

    var body: some View {
        Form {
            // Judging a matte by switching the whole screen on and off is
            // hopeless, so the sample carries the real wash and grain at the
            // real strength.
            Section("Preview") {
                PaperSwatch(texture: settings.paperTextureValue, strength: settings.paperStrength)
                    .padding(.vertical, 2)
            }

            Section("Texture") {
                SettingsRow(icon: "square.stack.3d.down.right.fill", tint: tint) {
                    Picker("Texture", selection: $settings.paperTexture) {
                        ForEach(PaperTexture.allCases) { texture in
                            Text(texture.title).tag(texture.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Text(settings.paperTextureValue.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Strength") {
                SettingsRow(icon: "dial.medium.fill", tint: tint) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.paperStrength) },
                            set: { settings.paperStrength = Int($0.rounded()) }
                        ),
                        in: Double(PaperStrength.range.lowerBound)...Double(PaperStrength.range.upperBound)
                    )
                    Text("\(settings.paperStrength)%")
                        .monospacedDigit()
                        .frame(minWidth: 42, alignment: .trailing)
                }
            }

            Section {
                if paper.isActive {
                    SettingsRow(icon: "camera.filters", tint: .green) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("On")
                                .fontWeight(.medium)
                            Text(paper.coveredScreens == 1
                                 ? "Covering 1 display"
                                 : "Covering \(paper.coveredScreens) displays")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            paper.deactivate()
                        } label: {
                            Text("Turn Off")
                        }
                    }
                } else {
                    SettingsRow(icon: "play.fill", tint: .green) {
                        Text("Lay the paper over your screens")
                        Spacer()
                        Button {
                            paper.activate()
                        } label: {
                            Text("Turn On")
                        }
                    }
                }
            }

            Section {
                Text("Paper lays a translucent matte over every display, so highlights diffuse and contrast softens. It takes no clicks or keystrokes, and it doesn't appear in screenshots, screen recordings or MiniMe's own captures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
