//
//  OnboardingSlideView.swift
//  MiniMe
//

import SwiftUI

/// One screen of the setup flow: the animation up top, then what the thing is
/// for, then the decision.
struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    @ObservedObject var onboarding: OnboardingManager
    @ObservedObject var settings: SettingsManager

    @State private var pointer: CGPoint?
    private let pointerSpace = "onboarding.welcome"

    var body: some View {
        switch slide {
        case .welcome:  welcome
        case .tool(let tool): toolSlide(tool)
        case .done:     done
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            AnimatedAboutIcon(pointer: pointer, space: pointerSpace, size: 96)
                .padding(.bottom, 26)

            Text("Welcome to MiniMe")
                .font(.system(size: 22, weight: .semibold))
                .padding(.bottom, 10)

            Text("Six small tools that live in your menu bar. Take a look at each one and keep the ones you want — you can change your mind later in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 42)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: pointerSpace)
        .onContinuousHover(coordinateSpace: .named(pointerSpace)) { phase in
            switch phase {
            case .active(let location): pointer = location
            case .ended: pointer = nil
            }
        }
    }

    // MARK: - Tool

    private func toolSlide(_ tool: Tool) -> some View {
        VStack(spacing: 0) {
            tool.onboardingScene
                .padding(.top, 30)
                .padding(.bottom, 26)

            Text(tool.title)
                .font(.system(size: 20, weight: .semibold))
                .padding(.bottom, 8)

            Text(tool.onboardingPurpose)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            Spacer(minLength: 18)

            VStack(spacing: 12) {
                Toggle(isOn: enablement(for: tool)) {
                    Text("Enable \(tool.title)")
                        .font(.system(size: 14, weight: .medium))
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("onboarding-toggle-\(tool.rawValue)")

                if let need = tool.permissionNeed, settings.isEnabled(tool) {
                    permissionRow(need, for: tool)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Writes straight through to `SettingsManager`, which persists and tears
    /// down immediately — there is no separate commit step, so closing the
    /// window early keeps whatever the user has already decided.
    private func enablement(for tool: Tool) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(tool) },
            set: { settings.setEnabled(tool, $0) }
        )
    }

    // MARK: - Permission row

    @ViewBuilder
    private func permissionRow(_ need: PermissionNeed, for tool: Tool) -> some View {
        // Reading the revision makes the row re-evaluate when polling notices a
        // grant, since `isGranted` asks the system rather than this object.
        let _ = onboarding.permissionRevision
        let granted = need.permission.isGranted
        let dismissed = tool == .clipboard && onboarding.isClipboardPromptDismissed

        if !granted && !dismissed {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: need.isRequired ? "exclamationmark.triangle.fill" : "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(need.isRequired ? .orange : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(need.isRequired
                         ? "\(tool.title) needs \(need.permission.title) permission."
                         : "Optional: grant \(need.permission.title) and picking an entry pastes it for you. Without it, entries are copied and you paste with ⌘V.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if !need.isRequired {
                            Button("Not now") { onboarding.dismissClipboardPrompt() }
                                .buttonStyle(.link)
                                .font(.system(size: 11.5))
                        }
                        Button("Grant") {
                            need.permission.openSystemSettings()
                            onboarding.beginWatchingForPermissionChange()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                (need.isRequired ? Color.orange : Color.secondary).opacity(0.09),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        } else if granted {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("\(need.permission.title) granted")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .font(.system(size: 11.5))
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Done

    private var done: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .padding(.bottom, 22)

            Text("You're set up")
                .font(.system(size: 21, weight: .semibold))
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Tool.allCases) { tool in
                    HStack(spacing: 8) {
                        Image(systemName: settings.isEnabled(tool) ? "checkmark" : "minus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(settings.isEnabled(tool) ? .green : .secondary)
                            .frame(width: 12)
                        Text(tool.title)
                            .font(.system(size: 13))
                            .foregroundStyle(settings.isEnabled(tool) ? .primary : .secondary)
                        Spacer(minLength: 0)
                        Text(settings.isEnabled(tool) ? "On" : "Off")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 220)
            .padding(.bottom, 20)

            Text("Change any of this in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
