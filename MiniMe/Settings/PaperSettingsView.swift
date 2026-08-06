//
//  PaperSettingsView.swift
//  MiniMe
//

import SwiftUI

struct PaperSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var paper = PaperOverlayManager.shared

    private let tint = Color.brown

    /// The one place the tab reports what the matte is doing, now that the
    /// on/off row is gone. Switching every display off is allowed, and this
    /// says so rather than leaving the matte looking broken.
    private var coverageSummary: String {
        guard paper.isActive else {
            return "Paper is off. \(settings.paperShortcut.displayString) turns it on."
        }
        switch paper.coveredScreens {
        case 0:  return "No displays selected — nothing is covered."
        case 1:  return "Covering 1 display."
        default: return "Covering \(paper.coveredScreens) displays."
        }
    }

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
                PaperTexturePicker(
                    selection: $settings.paperTexture,
                    strength: settings.paperStrength
                )
                .padding(.vertical, 2)

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
                    // The rendered opacity, not the slider's position — see
                    // `PaperStrength.percentLabel(for:)`.
                    Text(PaperStrength.percentLabel(for: settings.paperStrength))
                        .monospacedDigit()
                        .frame(minWidth: 42, alignment: .trailing)
                }

                // The scale reaches zero, so "on but showing nothing" is now a
                // state the user can reach. Said out loud, since the tab
                // otherwise reports the matte as covering displays it is
                // rendering invisibly.
                if PaperStrength.alpha(for: settings.paperStrength) == 0 {
                    Text("At zero the matte renders nothing.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // No on/off control here: the matte is switched by its hotkey and
            // its menu bar item, and a second switch in Settings only competed
            // with the one in General for the same meaning. What is left is
            // which displays it covers — sticky configuration that survives the
            // hotkey, the menu and a relaunch.
            if paper.displays.count > 1 {
                Section("Displays") {
                    ForEach(paper.displays) { display in
                        SettingsRow(icon: "display", tint: tint) {
                            Toggle(display.name, isOn: Binding(
                                get: { display.isCovered },
                                set: { paper.setCovered($0, for: display.id) }
                            ))
                            .toggleStyle(.switch)
                        }
                    }

                    Text(coverageSummary)
                        .font(.caption)
                        .foregroundStyle(paper.isActive && paper.coveredScreens == 0 ? .orange : .secondary)
                }
            }

            Section {
                Text("Paper lays a translucent matte over the displays you choose, so highlights diffuse and contrast softens. It takes no clicks or keystrokes, and it doesn't appear in screenshots, screen recordings or MiniMe's own captures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
