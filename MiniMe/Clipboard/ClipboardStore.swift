//
//  ClipboardStore.swift
//  MiniMe
//

import SwiftUI

/// File-backed store for clipboard history.
///
/// Metadata lives in `clipboard.json`; image blobs and cached thumbnails live in
/// `ClipboardBlobs/`. UserDefaults (used by `CaptureHistoryStore`) is unsuitable
/// here because it is loaded wholesale and rewritten on every change, and image
/// blobs make the payload far too large for that.
@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []

    let blobsDirectory: URL
    private let metadataURL: URL

    var maxEntries: Int {
        didSet {
            guard maxEntries != oldValue else { return }
            evict()
            save()
        }
    }

    init(directory: URL = ClipboardStore.defaultDirectory(), maxEntries: Int = 200) {
        self.blobsDirectory = directory.appendingPathComponent("ClipboardBlobs", isDirectory: true)
        self.metadataURL = directory.appendingPathComponent("clipboard.json")
        self.maxEntries = maxEntries

        // Creating the blobs directory with intermediates also creates `directory`.
        try? FileManager.default.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)

        load()
        evict()
        sweepOrphanedBlobs()
    }

    nonisolated static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("MiniMe", isDirectory: true)
    }

    func blobURL(named fileName: String) -> URL {
        blobsDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Mutation

    /// Adds `entry`, or — when an entry with identical content already exists —
    /// moves that entry to the top and refreshes its timestamp. Returns the entry
    /// that ended up at position 0, which is the one callers should thumbnail.
    ///
    /// Images are exempt from deduplication: comparing pixel data on every
    /// clipboard change is not worth the cost.
    @discardableResult
    func add(_ entry: ClipboardEntry) -> ClipboardEntry {
        if !entry.content.isImage,
           let index = entries.firstIndex(where: { $0.content == entry.content }) {
            var existing = entries.remove(at: index)
            existing.timestamp = entry.timestamp
            entries.insert(existing, at: 0)
            save()
            return existing
        }

        entries.insert(entry, at: 0)
        evict()
        save()
        return entry
    }

    func setThumbnail(_ fileName: String, forEntry id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].thumbnailFileName = fileName
        save()
    }

    func delete(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        deleteBlobs(for: entry)
        save()
    }

    func clearAll() {
        for entry in entries { deleteBlobs(for: entry) }
        entries.removeAll()
        save()
    }

    @discardableResult
    func writeBlob(_ data: Data, named fileName: String) -> Bool {
        do {
            try data.write(to: blobURL(named: fileName), options: .atomic)
            return true
        } catch {
            print("[ClipboardStore] Failed to write blob \(fileName): \(error)")
            return false
        }
    }

    // MARK: - Housekeeping

    private func evict() {
        guard entries.count > maxEntries else { return }
        for entry in entries[maxEntries...] { deleteBlobs(for: entry) }
        entries = Array(entries.prefix(maxEntries))
    }

    private func blobNames(for entry: ClipboardEntry) -> [String] {
        var names: [String] = []
        if case .image(let fileName, _, _) = entry.content { names.append(fileName) }
        if let thumbnail = entry.thumbnailFileName { names.append(thumbnail) }
        return names
    }

    private func deleteBlobs(for entry: ClipboardEntry) {
        for name in blobNames(for: entry) {
            try? FileManager.default.removeItem(at: blobURL(named: name))
        }
    }

    /// Deletes blob files no entry references. Recovers space after a crash
    /// between writing a blob and writing the metadata that points at it.
    private func sweepOrphanedBlobs() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: blobsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        let referenced = Set(entries.flatMap(blobNames(for:)))
        for url in contents where !referenced.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        do {
            entries = try JSONDecoder().decode([ClipboardEntry].self, from: data)
        } catch {
            // Start empty rather than crashing, and leave the file in place so a
            // decoding regression is recoverable.
            print("[ClipboardStore] Failed to decode clipboard history: \(error)")
            entries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("[ClipboardStore] Failed to save clipboard history: \(error)")
        }
    }
}
