//
//  UpdateManager.swift
//  MiniMe
//

import SwiftUI

@MainActor
class UpdateManager: ObservableObject {
    @Published private(set) var latestVersion: String? = nil
    @Published private(set) var releaseURL: URL? = nil
    @Published private(set) var isChecking = false
    @Published private(set) var checkedAtLeastOnce = false

    var updateAvailable: Bool {
        guard let latest = latestVersion,
              let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return false }
        return isVersionNewer(latest, than: current)
    }

    private let repoOwner = "marduc812"
    private let repoName  = "kimeno"

    /// Called on launch - skips fetch if checked within the last 24 hours.
    func checkForUpdatesIfNeeded() async {
        let lastCheck = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 86400 { return }
        await fetch()
    }

    /// Always fetches, regardless of last check time.
    func checkNow() async {
        await fetch()
    }

    private func fetch() async {
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
                UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = version
                releaseURL = URL(string: htmlURL)
            }
        } catch {
            // Non-critical - silently ignore network errors
        }
    }

    private func isVersionNewer(_ candidate: String, than current: String) -> Bool {
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
}
