//
//  MouseMoverSettingsView.swift
//  MiniMe
//

import SwiftUI

struct MouseMoverSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var mover = MouseMoverManager.shared

    private let tint = Color.indigo

    var body: some View {
        Form {
            Section("Interval between moves") {
                SettingsRow(icon: "arrow.down.to.line", tint: tint) {
                    Text("At least")
                    Spacer()
                    Text("\(settings.mouseMoverMinSeconds) sec")
                        .monospacedDigit()
                        .frame(minWidth: 52, alignment: .trailing)
                    Stepper("", value: $settings.mouseMoverMinSeconds, in: 1...3600)
                        .labelsHidden()
                }
                .disabled(mover.isArmed)

                SettingsRow(icon: "arrow.up.to.line", tint: tint) {
                    Text("At most")
                    Spacer()
                    Text("\(max(settings.mouseMoverMaxSeconds, settings.mouseMoverMinSeconds)) sec")
                        .monospacedDigit()
                        .frame(minWidth: 52, alignment: .trailing)
                    Stepper("", value: $settings.mouseMoverMaxSeconds,
                            in: settings.mouseMoverMinSeconds...3600)
                        .labelsHidden()
                }
                .disabled(mover.isArmed)
            }

            Section {
                if mover.isArmed {
                    SettingsRow(icon: "cursorarrow.motionlines", tint: .green) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Moving")
                                .fontWeight(.medium)
                            if let next = mover.nextMoveDate {
                                let countdown = Text(timerInterval: Date()...next, countsDown: true)
                                    .monospacedDigit()
                                Text("Next move in \(countdown)")
                                    .font(.caption)
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
                    SettingsRow(icon: "play.fill", tint: .green) {
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
    }
}
