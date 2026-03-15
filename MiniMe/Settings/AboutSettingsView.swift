//
//  AboutSettingsView.swift
//  MiniMe
//

import SwiftUI

struct AboutSettingsView: View {
    @ObservedObject var updateManager: UpdateManager

    @State private var iconRotation: Double = 0
    @State private var showUpToDate = false

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("MenuBarIcon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                Text("MiniMe")
                    .font(.system(size: 20, weight: .semibold))

                Text("Version \(currentVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Status area - fixed height to prevent layout jumps
            ZStack {
                // Update available banner
                if updateManager.updateAvailable, let latest = updateManager.latestVersion {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("Version \(latest) is available")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        if let url = updateManager.releaseURL {
                            Link("Download", destination: url)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.green.opacity(0.3), lineWidth: 0.5)
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                // Checking indicator
                if updateManager.isChecking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text("Checking for updates…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

                // Up to date confirmation
                if showUpToDate {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You're up to date")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.25), value: updateManager.isChecking)
            .animation(.easeInOut(duration: 0.25), value: updateManager.updateAvailable)
            .animation(.easeInOut(duration: 0.25), value: showUpToDate)

            VStack(spacing: 4) {
                Text("Screen OCR · Type It · Capture History")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Capture text from anywhere on your screen, retype it into any app, keep a searchable history, and prevent your Mac from sleeping - all from the menu bar.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/marduc812/kimeno")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                        Text("View on GitHub")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await updateManager.checkNow() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(iconRotation))
                        Text("Check for Updates")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .opacity(updateManager.isChecking ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(updateManager.isChecking)
            }

            Spacer()

            Text("© 2026 MiniMe")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: updateManager.isChecking) { _, checking in
            if checking {
                // Start spinning
                withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                    iconRotation = 360
                }
                showUpToDate = false
            } else {
                // Stop spinning at nearest full rotation
                withAnimation(.linear(duration: 0.2)) {
                    iconRotation = 0
                }
                // Show "up to date" briefly if no update found
                if updateManager.checkedAtLeastOnce && !updateManager.updateAvailable {
                    showUpToDate = true
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { showUpToDate = false }
                    }
                }
            }
        }
    }
}
