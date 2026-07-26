//
//  ClipboardEntry.swift
//  MiniMe
//

import Foundation

enum ClipboardContent: Codable, Hashable {
    case text(String)
    case image(fileName: String, pixelWidth: Int, pixelHeight: Int)
    case files(paths: [String])

    var isImage: Bool {
        if case .image = self { return true }
        return false
    }
}

struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let content: ClipboardContent
    let title: String
    var timestamp: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?
    var thumbnailFileName: String?

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        timestamp: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil,
        thumbnailFileName: String? = nil
    ) {
        self.id = id
        self.content = content
        self.title = ClipboardEntry.generateTitle(for: content)
        self.timestamp = timestamp
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.thumbnailFileName = thumbnailFileName
    }

    static func generateTitle(for content: ClipboardContent) -> String {
        switch content {
        case .text(let string):
            let firstNonEmpty = string
                .components(separatedBy: .newlines)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let trimmed = (firstNonEmpty ?? "").trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "Untitled" }
            if trimmed.count <= 50 { return trimmed }
            return String(trimmed.prefix(47)) + "..."

        case .image(_, let width, let height):
            return "Image \(width)×\(height)"

        case .files(let paths):
            if paths.count == 1 {
                return (paths[0] as NSString).lastPathComponent
            }
            return "\(paths.count) files"
        }
    }

    /// True if `query` appears in the title, or — for text and file entries — in
    /// the full text or any file name. Image entries are matchable by title only.
    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }

        if title.localizedCaseInsensitiveContains(needle) { return true }

        switch content {
        case .text(let string):
            return string.localizedCaseInsensitiveContains(needle)
        case .files(let paths):
            return paths.contains {
                ($0 as NSString).lastPathComponent.localizedCaseInsensitiveContains(needle)
            }
        case .image:
            return false
        }
    }
}
