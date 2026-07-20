//
//  MouseMoverSettingsView.swift
//  MiniMe
//

import SwiftUI

struct MouseMoverSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var mover = MouseMoverManager.shared

    var body: some View {
        Form {
            Section("Interval between moves") {
                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "arrow.down.to.line", color: .indigo)
                    Text("At least")
                        .fixedSize()
                    Spacer()
                    Stepper(value: $settings.mouseMoverMinSeconds, in: 1...3600) {
                        Text("\(settings.mouseMoverMinSeconds) sec")
                            .monospacedDigit()
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                    .fixedSize()
                }
                .disabled(mover.isArmed)

                HStack(spacing: 10) {
                    SettingsRowIcon(systemName: "arrow.up.to.line", color: .indigo)
                    Text("At most")
                        .fixedSize()
                    Spacer()
                    Stepper(value: $settings.mouseMoverMaxSeconds,
                            in: settings.mouseMoverMinSeconds...3600) {
                        Text("\(max(settings.mouseMoverMaxSeconds, settings.mouseMoverMinSeconds)) sec")
                            .monospacedDigit()
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                    .fixedSize()
                }
                .disabled(mover.isArmed)
            }

            Section {
                if mover.isArmed {
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "cursorarrow.motionlines", color: .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Moving")
                                .fontWeight(.medium)
                            if let next = mover.nextMoveDate {
                                Text("Next move in ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                + Text(timerInterval: Date()...next, countsDown: true)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            mover.disarm()
                        } label: {
                            Text("Stop")
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        SettingsRowIcon(systemName: "play.fill", color: .green)
                        Text("Start moving the mouse")
                        Spacer()
                        Button {
                            mover.arm(
                                minInterval: Double(settings.mouseMoverMinSeconds),
                                maxInterval: Double(settings.mouseMoverMaxSeconds)
                            )
                        } label: {
                            Text("Start")
                        }
                    }
                }
            }

            Section {
                Text("When started, MiniMe keeps the cursor drifting to random points inside a 600×600 area around wherever it is right now — useful for keeping a session awake. Each move waits a random time in the range above. Movement pauses while your Mac is asleep, and stops if you press Stop or quit MiniMe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }
}
