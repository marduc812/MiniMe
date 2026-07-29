//
//  SchedulerSettingsView.swift
//  MiniMe
//

import SwiftUI

struct SchedulerSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var scheduler = ScheduledActionManager.shared

    private let tint = Color.pink

    /// Allowed range for the interval amount — enforced by both the stepper and typed entry.
    private static let intervalRange = 1...999

    private var intervalSeconds: TimeInterval {
        let unit = ScheduleUnit(rawValue: settings.scheduledIntervalUnit) ?? .hours
        return Double(settings.scheduledIntervalValue) * unit.multiplier
    }

    var body: some View {
        Form {
            Section("Timing") {
                SettingsRow(icon: "timer", tint: tint) {
                    Text("Run after")
                    Spacer()
                    TextField("", value: $settings.scheduledIntervalValue, format: .number)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 56)
                        .onChange(of: settings.scheduledIntervalValue) { _, value in
                            let clamped = min(max(value, Self.intervalRange.lowerBound),
                                              Self.intervalRange.upperBound)
                            if clamped != value { settings.scheduledIntervalValue = clamped }
                        }
                    Stepper("", value: $settings.scheduledIntervalValue, in: Self.intervalRange)
                        .labelsHidden()
                    Picker("", selection: $settings.scheduledIntervalUnit) {
                        ForEach(ScheduleUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
                .disabled(scheduler.isArmed)

                SettingsRow(icon: "repeat", tint: tint) {
                    Toggle("Repeat on this interval", isOn: $settings.scheduledRepeat)
                }
                .disabled(scheduler.isArmed)
            }

            Section("Action") {
                SettingsRow(icon: "text.cursor", tint: tint, alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Text to type")
                        MultilineTextEditor(label: "Text to type",
                                            placeholder: "Leave empty to type nothing",
                                            text: $settings.scheduledText)
                        Text("Each line break is typed as a Return press.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(scheduler.isArmed)

                SettingsRow(icon: "return", tint: tint) {
                    Toggle("Then press a key", isOn: $settings.scheduledComboEnabled)
                    Spacer()
                    ShortcutRecorderButton(shortcut: $settings.scheduledCombo, requiresModifier: false)
                        .disabled(!settings.scheduledComboEnabled)
                        .opacity(settings.scheduledComboEnabled ? 1 : 0.4)
                }
                .disabled(scheduler.isArmed)
            }

            Section {
                if scheduler.isArmed {
                    SettingsRow(icon: "clock.badge.checkmark", tint: .green) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Armed")
                                .fontWeight(.medium)
                            if let fire = scheduler.nextFireDate {
                                let countdown = Text(timerInterval: Date()...fire, countsDown: true)
                                    .monospacedDigit()
                                Text("Next in \(countdown)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            scheduler.disarm()
                        } label: {
                            Text("Stop")
                        }
                    }
                } else {
                    SettingsRow(icon: "play.fill", tint: .green) {
                        Text("Start the schedule")
                        Spacer()
                        Button {
                            scheduler.arm(
                                text: settings.scheduledText,
                                combo: settings.scheduledComboEnabled ? settings.scheduledCombo : nil,
                                interval: intervalSeconds,
                                repeats: settings.scheduledRepeat
                            )
                        } label: {
                            Text("Start")
                        }
                        .disabled(settings.scheduledText.isEmpty && !settings.scheduledComboEnabled)
                    }
                }
            }

            Section {
                Text("After the delay, MiniMe types the text and presses the key into whichever window is focused at that moment. The timer pauses while your Mac is asleep — pair it with Prevent Sleep for long delays. The schedule is cancelled if you quit MiniMe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
