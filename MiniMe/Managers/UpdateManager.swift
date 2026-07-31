//
//  UpdateManager.swift
//  MiniMe
//

import SwiftUI
import UserNotifications

/// Pure decision logic for update checking, kept free of timers, networking and
/// UserDefaults so it can be tested directly.
enum UpdateCheckPolicy {
    /// How long to wait between automatic checks.
    static let checkInterval: TimeInterval = 86_400

    /// Compares dotted version strings component by component. Missing
    /// components count as zero, so "1.1" is newer than "1.0.9".
    static func isVersionNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }

    /// The hourly timer calls this on every tick; it only lets a fetch through
    /// once a day. Comparing wall-clock times rather than counting timer
    /// firings means a Mac that slept through the interval still checks on the
    /// first tick after waking.
    static func shouldCheck(lastCheck: Date?, now: Date, automaticChecksEnabled: Bool) -> Bool {
        guard automaticChecksEnabled else { return false }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= checkInterval
    }

    /// Notify once per version. Being on 1.0.12 with 1.0.13 out earns exactly
    /// one banner, no matter how many daily checks confirm it.
    static func shouldNotify(latest: String?, current: String, lastNotified: String?) -> Bool {
        guard let latest, isVersionNewer(latest, than: current) else { return false }
        return latest != lastNotified
    }
}

@MainActor
class UpdateManager: ObservableObject {
    @Published private(set) var latestVersion: String? = nil
    @Published private(set) var releaseURL: URL? = nil
    @Published private(set) var isChecking = false
    @Published private(set) var checkedAtLeastOnce = false

    /// Key carried in a notification's `userInfo`, so the delegate can tell an
    /// update banner apart from the capture banners the app also posts.
    nonisolated static let releaseURLUserInfoKey = "updateReleaseURL"

    private static let lastCheckKey = "lastUpdateCheck"
    private static let lastNotifiedKey = "lastNotifiedUpdateVersion"
    private static let automaticChecksKey = "automaticUpdateChecks"

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return UpdateCheckPolicy.isVersionNewer(latest, than: currentVersion)
    }

    private let repoOwner = "marduc812"
    private let repoName  = "MiniMe"

    private var timer: Timer?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Defaults to on, so a user who has never touched the toggle still gets
    /// checks.
    private var automaticChecksEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.automaticChecksKey) as? Bool ?? true
    }

    /// Checks now if a day has passed, then keeps checking for as long as the
    /// app runs — a menu bar app can stay open for weeks, so a launch-only
    /// check would never come round again.
    ///
    /// The timer ticks hourly rather than daily because timers do not fire
    /// while the Mac sleeps and a 24-hour schedule silently slips a little
    /// further behind with every sleep. Each tick is almost free: the daily
    /// throttle in `checkForUpdatesIfNeeded()` turns nearly all of them away.
    func startPeriodicChecks() {
        Task { await checkForUpdatesIfNeeded() }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdatesIfNeeded()
            }
        }
    }

    /// Skips the fetch unless automatic checks are on and a day has passed.
    func checkForUpdatesIfNeeded() async {
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        guard UpdateCheckPolicy.shouldCheck(
            lastCheck: lastCheck,
            now: Date(),
            automaticChecksEnabled: automaticChecksEnabled
        ) else { return }

        await fetch(notifyOnUpdate: true)
    }

    /// Always fetches, regardless of last check time or the automatic setting.
    /// Posts no notification: the result appears in the About pane the user is
    /// looking at.
    func checkNow() async {
        await fetch(notifyOnUpdate: false)
    }

    private func fetch(notifyOnUpdate: Bool) async {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else { return }
        isChecking = true
        defer {
            isChecking = false
            checkedAtLeastOnce = true
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String,
               let htmlURL = json["html_url"] as? String {
                // Only a parsed response counts as a check, so a spell offline
                // retries on the next tick instead of burning the whole day.
                UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = version
                releaseURL = URL(string: htmlURL)

                if notifyOnUpdate { notifyIfUpdateIsNew() }
            }
        } catch {
            // Non-critical - silently ignore network errors
        }
    }

    private func notifyIfUpdateIsNew() {
        let lastNotified = UserDefaults.standard.string(forKey: Self.lastNotifiedKey)
        guard UpdateCheckPolicy.shouldNotify(
            latest: latestVersion,
            current: currentVersion,
            lastNotified: lastNotified
        ), let latest = latestVersion else { return }

        let content = UNMutableNotificationContent()
        content.title = "MiniMe \(latest) is available"
        content.body = "You're on \(currentVersion). Click to download."
        content.sound = .default
        if let releaseURL {
            content.userInfo = [Self.releaseURLUserInfoKey: releaseURL.absoluteString]
        }

        // Identifier keyed by version, so a re-post can only ever replace the
        // banner for that version rather than stack up beside it.
        let request = UNNotificationRequest(
            identifier: "update-available-\(latest)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)

        UserDefaults.standard.set(latest, forKey: Self.lastNotifiedKey)
    }
}
