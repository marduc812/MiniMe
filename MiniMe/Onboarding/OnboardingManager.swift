//
//  OnboardingManager.swift
//  MiniMe
//

import SwiftUI

/// Owns the setup flow: which slide is showing, whether the window is up, and
/// the polling that notices a permission being granted in System Settings.
///
/// The slide sequence itself lives in `OnboardingDeck`; this type is the part
/// with side effects.
@MainActor
final class OnboardingManager: ObservableObject {
    @Published private(set) var deck = OnboardingDeck()
    @Published var isPresented = false

    /// Bumped whenever polling notices a permission change, so slides observing
    /// this object re-read `OnboardingPermission.isGranted`.
    @Published private(set) var permissionRevision = 0

    private let defaults: UserDefaults
    private var permissionTimer: Timer?

    private let completedKey = "hasCompletedOnboarding"
    private let clipboardPromptDismissedKey = "clipboardAccessibilityPromptDismissed"

    /// Injectable so tests can run against a scratch domain instead of the
    /// user's real preferences.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    deinit {
        permissionTimer?.invalidate()
    }

    // MARK: - Presentation

    var shouldPresentOnLaunch: Bool {
        !defaults.bool(forKey: completedKey)
    }

    /// Shows the full wizard from the beginning.
    func restartWizard() {
        deck = OnboardingDeck()
        isPresented = true
        startPollingIfNeeded()
    }

    /// Shows one tool's slide on its own — the path taken when a permission is
    /// found missing during normal use. Deliberately does not clear the
    /// completion flag: fixing a revoked permission is not first-run setup.
    func presentSingle(_ tool: Tool) {
        deck = OnboardingDeck(singleTool: tool)
        isPresented = true
        startPollingIfNeeded()
    }

    /// Closes the flow and records it as done, wherever the user had got to.
    /// Every switch has already written through `SettingsManager`, so there is
    /// no pending state to commit or discard here.
    func finish() {
        defaults.set(true, forKey: completedKey)
        stopPolling()
        isPresented = false
    }

    // MARK: - Navigation

    func advance() { deck.advance() }
    func goBack() { deck.goBack() }

    // MARK: - The optional Clipboard prompt

    var isClipboardPromptDismissed: Bool {
        defaults.bool(forKey: clipboardPromptDismissedKey)
    }

    /// "Not now" on the Clipboard slide's Accessibility row. Answers the
    /// question for good — a later "Run Setup Again…" does not re-ask it.
    func dismissClipboardPrompt() {
        objectWillChange.send()
        defaults.set(true, forKey: clipboardPromptDismissedKey)
    }

    // MARK: - Permission polling

    /// Permission grants happen in System Settings, out of the app's sight, and
    /// neither check has a change notification — so while the window is open and
    /// something is still missing, poll for it.
    private func startPollingIfNeeded() {
        stopPolling()
        guard hasOutstandingPermission else { return }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.permissionRevision += 1
                if !self.hasOutstandingPermission { self.stopPolling() }
            }
        }
    }

    private var hasOutstandingPermission: Bool {
        OnboardingPermission.allCases.contains { !$0.isGranted }
    }

    func stopPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    /// Called when a Grant button sends the user to System Settings, so the app
    /// starts watching for them coming back having granted it.
    func beginWatchingForPermissionChange() {
        startPollingIfNeeded()
    }
}
