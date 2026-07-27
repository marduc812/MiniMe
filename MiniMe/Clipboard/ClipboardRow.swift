//
//  ClipboardRow.swift
//  MiniMe
//

import SwiftUI

enum ClipboardIconResolver {
    /// Resolves an app icon, preferring the bundle identifier. `CaptureRow` matches
    /// on localized name and guesses a path in /Applications, which breaks for apps
    /// installed elsewhere; bundle ID lookup is exact.
    static func appIcon(bundleID: String?, name: String?) -> NSImage? {
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

    /// Same scheme as `CaptureRow.relativeTime`, kept consistent across both lists.
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
}

struct ClipboardRow: View {
    let entry: ClipboardEntry
    let store: ClipboardStore
    let shortcutIndex: Int?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    /// File entries whose files have since moved or been deleted.
    private var isUnavailable: Bool {
        if case .files(let paths) = entry.content {
            return !paths.allSatisfy { FileManager.default.fileExists(atPath: $0) }
        }
        return false
    }

    private var thumbnail: NSImage? {
        guard let name = entry.thumbnailFileName else { return nil }
        return NSImage(contentsOf: store.blobURL(named: name))
    }

    private var fallbackSymbol: String {
        switch entry.content {
        case .text:  return "text.alignleft"
        case .image: return "photo"
        case .files: return "doc"
        }
    }

    private var secondLine: String? {
        guard case .text(let string) = entry.content else { return nil }
        let rest = string.components(separatedBy: .newlines).dropFirst()
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            shortcutBadge

            preview

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let secondLine {
                    Text(secondLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if isUnavailable {
                    Text("File no longer available")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                footer
            }

            Spacer(minLength: 0)
        }
        .opacity(isUnavailable ? 0.5 : 1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.25))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
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
    private var shortcutBadge: some View {
        if let shortcutIndex {
            Text("⌘\(shortcutIndex)")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 2)
        } else {
            Color.clear.frame(width: 24, height: 1)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch entry.content {
        case .text:
            EmptyView()
        case .image, .files:
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if let icon = ClipboardIconResolver.appIcon(
                bundleID: entry.sourceAppBundleID,
                name: entry.sourceAppName
            ) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 11, height: 11)
            }
            if let name = entry.sourceAppName {
                Text(name)
            }
            Text("·")
            Text(ClipboardIconResolver.relativeTime(from: entry.timestamp))
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }
}
