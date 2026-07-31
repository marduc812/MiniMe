//
//  OnboardingView.swift
//  MiniMe
//

import SwiftUI

/// The setup window: a slide deck on first run, or a single tool's slide when a
/// permission has gone missing during normal use.
struct OnboardingView: View {
    @ObservedObject var onboarding: OnboardingManager
    @ObservedObject var settings: SettingsManager

    private var deck: OnboardingDeck { onboarding.deck }

    var body: some View {
        VStack(spacing: 0) {
            if deck.isWizard {
                dots.padding(.top, 18)
            }

            OnboardingSlideView(
                slide: deck.current,
                onboarding: onboarding,
                settings: settings
            )
            .id(deck.current.id)
            .transition(.opacity)

            Divider().opacity(0.5).padding(.horizontal, 24)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
        }
        .frame(width: 460, height: 580)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
    }

    // MARK: - Progress

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(Array(deck.slides.enumerated()), id: \.element.id) { position, _ in
                Circle()
                    .fill(position == deck.index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if deck.isWizard {
            HStack {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.18)) { onboarding.goBack() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!deck.canGoBack)

                Spacer()

                Button(deck.isOnLastSlide ? "Done" : "Next") {
                    if deck.isOnLastSlide {
                        onboarding.finish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) { onboarding.advance() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        } else {
            Button("Done") { onboarding.finish() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity)
        }
    }
}
