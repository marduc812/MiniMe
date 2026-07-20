//
//  SchedulerSettingsView.swift
//  MiniMe
//

import SwiftUI

struct SchedulerSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var scheduler = ScheduledActionManager.shared

    private var intervalSeconds: TimeInterval {
        let unit = ScheduleUnit(rawValue: settings.scheduledIntervalUnit) ?? .hours
        return Double(settings.scheduledIntervalValue) * unit.multiplier
    }

    var body: some View {
        Form {
            Section("Timing") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "timer", color: .pink)
                    Text("Run after")
                    Spacer()
                    Text("\(settings.scheduledIntervalValue)")
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.scheduledIntervalValue, in: 1...999)
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

                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "repeat", color: .pink)
                    Toggle("Repeat on this interval", isOn: $settings.scheduledRepeat)
                }
                .disabled(scheduler.isArmed)
            }

            Section("Action") {
                HStack(alignment: .top, spacing: 10) {
                    SettingsRowIcon(systemName: "text.cursor", color: .purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text to type")
                        TextField("Leave empty to type nothing", text: $settings.scheduledText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)
                    }
                }
                .disabled(scheduler.isArmed)

                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "return", color: .purple)
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
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "clock.badge.checkmark", color: .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Armed")
                                .fontWeight(.medium)
                            if let fire = scheduler.nextFireDate {
                                Text("Next in ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                + Text(timerInterval: Date()...fire, countsDown: true)
                                    .font(.caption.monospacedDigit())
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
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "play.fill", color: .green)
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
        .padding(.top, 4)
    }
}
