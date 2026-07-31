//
//  ClipboardRow.swift
//  MiniMe
//

import SwiftUI

@MainActor
enum ClipboardIconResolver {
    /// Resolved app icons, keyed by bundle ID or name. The LaunchServices lookup
    /// behind them costs ~0.7 ms and the detail pane redraws on every hover, so
    /// misses are cached too — an app that cannot be resolved is not worth
    /// asking about again for the life of the process.
    private static var iconCache: [String: NSImage?] = [:]

    /// Resolves an app icon, preferring the bundle identifier. Matching on localized
    /// name means guessing a path in /Applications, which breaks for apps installed
    /// elsewhere; bundle ID lookup is exact, with the name only as a fallback.
    static func appIcon(bundleID: String?, name: String?) -> NSImage? {
        guard let key = bundleID ?? name else { return nil }
        if let cached = iconCache[key] { return cached }
        let icon = lookUpAppIcon(bundleID: bundleID, name: name)
        iconCache[key] = icon
        return icon
    }

    private static func lookUpAppIcon(bundleID: String?, name: String?) -> NSImage? {
        if let bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let name,
           let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }),
           let url = running.bundleURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    /// Compact relative age ("<1 min", "3h", "2d") for the row's trailing label.
    static func relativeTime(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "<1 min" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 30 { return "\(days)d" }
        let months = days / 30
        if months < 12 { return "\(months)mo" }
        return "\(months / 12)y"
    }

    /// Text entries are icon'd by what they contain — a link, an email address,
    /// JSON, a date, a hex value, a UUID — so the list is scannable by shape.
    static func symbol(for entry: ClipboardEntry) -> String {
        switch entry.content {
        case .text:  return ClipboardTextKindCache.kind(for: entry).symbolName
        case .image: return "photo"
        case .files: return "doc"
        }
    }
}

/// A deliberately minimal list row: type icon, single-line title, age, and the
/// ⌘1–9 badge at the trailing edge. Everything richer lives in the detail pane.
struct ClipboardRow: View, Equatable {
    let entry: ClipboardEntry
    let store: ClipboardStore
    let shortcutIndex: Int?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var isHovered = false

    /// Everything the row draws comes from these three; the closures are pure
    /// callbacks over the same `entry`, and `store` is one object for the life
    /// of the app. Hovering re-creates every row in the list, so without this
    /// SwiftUI redraws all of them instead of the two that actually changed.
    nonisolated static func == (lhs: ClipboardRow, rhs: ClipboardRow) -> Bool {
        lhs.entry == rhs.entry
            && lhs.shortcutIndex == rhs.shortcutIndex
            && lhs.isSelected == rhs.isSelected
    }

    private var thumbnail: NSImage? {
        guard let name = entry.thumbnailFileName else { return nil }
        return store.thumbnail(named: name)
    }

    var body: some View {
        // Hits the filesystem, so it is resolved once per draw rather than once
        // for the warning badge and again for the dimming.
        let isMissing = entry.hasMissingFiles

        HStack(spacing: 9) {
            leadingIcon

            Text(entry.title)
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange.opacity(0.8))
            }

            Text(ClipboardIconResolver.relativeTime(from: entry.timestamp))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            shortcutBadge
        }
        .opacity(isMissing ? 0.55 : 1)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.22))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            onHoverChange(hovering)
        }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(action: onSelect) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            Image(systemName: ClipboardIconResolver.symbol(for: entry))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        if let shortcutIndex {
            Text("⌘\(shortcutIndex)")
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}
