//
//  ClipboardStore.swift
//  MiniMe
//

import SwiftUI

/// File-backed store for clipboard history.
///
/// Metadata lives in `clipboard.json`; image blobs and cached thumbnails live in
/// `ClipboardBlobs/`. UserDefaults is unsuitable here because it is loaded wholesale
/// and rewritten on every change, and image blobs make the payload far too large
/// for that.
@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []

    let blobsDirectory: URL
    private let metadataURL: URL
    private let io: DispatchQueue
    private var isLoading = true
    private var isReplaying = false
    private var loadedWaiters: [CheckedContinuation<Void, Never>] = []
    private var pendingMutations: [Mutation] = []
    private var fileAccess: [UUID: [URL]] = [:]

    private enum Mutation {
        case add(ClipboardEntry), move(UUID, Date), thumbnail(String, UUID), delete(UUID), clear
    }

    /// Decoded row thumbnails, keyed by blob file name. `ClipboardRow` asks for
    /// its thumbnail every time it draws and decoding a 240pt PNG costs ~0.9 ms,
    /// so without this every hover re-decodes every visible thumbnail.
    private let thumbnailCache = NSCache<NSString, NSImage>()

    var maxEntries: Int {
        didSet {
            guard maxEntries != oldValue else { return }
            evict()
            save()
        }
    }

    init(directory: URL = ClipboardStore.defaultDirectory(), maxEntries: Int = 200,
         ioQueue: DispatchQueue = DispatchQueue(label: "com.minime.clipboard-store", qos: .utility)) {
        self.io = ioQueue
        self.blobsDirectory = directory.appendingPathComponent("ClipboardBlobs", isDirectory: true)
        self.metadataURL = directory.appendingPathComponent("clipboard.json")
        self.maxEntries = maxEntries
        // One thumbnail per entry is the ceiling; NSCache also sheds under
        // memory pressure, so this only bounds a pathological growth case.
        self.thumbnailCache.countLimit = 200

        let blobs = blobsDirectory
        let metadata = metadataURL
        io.async { [weak self] in
            try? FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
            let result = Self.loadHistory(metadata: metadata, blobs: blobs)
            Task { @MainActor [weak self] in self?.finishLoading(result) }
        }
    }

    nonisolated static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("MiniMe", isDirectory: true)
    }

    deinit {
        let urls = fileAccess.values.flatMap { $0 }
        io.async { for url in urls { url.stopAccessingSecurityScopedResource() } }
    }

    func resolveFileAccess(_ bookmarks: [Data]) async -> [URL] {
        guard !bookmarks.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            io.async {
                let urls = bookmarks.compactMap { bookmark -> URL? in
                    var stale = false
                    return try? URL(resolvingBookmarkData: bookmark, options: .withoutUI,
                                    relativeTo: nil, bookmarkDataIsStale: &stale)
                }
                continuation.resume(returning: urls)
            }
        }
    }

    func retainFileAccess(_ urls: [URL], forEntry id: UUID) {
        guard !urls.isEmpty else { return }
        releaseFileAccess(fileAccess.updateValue(urls, forKey: id) ?? [])
    }

    func releaseFileAccess(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        io.async { for url in urls { url.stopAccessingSecurityScopedResource() } }
    }

    func blobURL(named fileName: String) -> URL {
        blobsDirectory.appendingPathComponent(fileName)
    }

    /// The decoded thumbnail for `fileName`, read from disk once and kept.
    func thumbnail(named fileName: String) -> NSImage? {
        let key = fileName as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: blobURL(named: fileName)) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
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
        if isLoading { pendingMutations.append(.add(entry)) }
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

    /// Marks a selected history entry as the most recent without creating a copy.
    func moveToTop(id: UUID, at date: Date = Date()) {
        if isLoading { pendingMutations.append(.move(id, date)) }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: index)
        entry.timestamp = date
        entries.insert(entry, at: 0)
        save()
    }

    func setThumbnail(_ fileName: String, forEntry id: UUID) {
        if isLoading { pendingMutations.append(.thumbnail(fileName, id)) }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].thumbnailFileName = fileName
        save()
    }

    func delete(id: UUID) {
        if isLoading { pendingMutations.append(.delete(id)) }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        deleteBlobs(for: entry)
        save()
    }

    func clearAll() {
        if isLoading { pendingMutations.append(.clear) }
        for entry in entries { deleteBlobs(for: entry) }
        entries.removeAll()
        save()
    }

    @discardableResult
    func writeBlob(_ data: Data, named fileName: String) async -> Bool {
        let url = blobURL(named: fileName)
        return await withCheckedContinuation { continuation in
            io.async {
                do {
                    try data.write(to: url, options: .atomic)
                    continuation.resume(returning: true)
                } catch {
                    print("[ClipboardStore] Failed to write blob: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func removeBlob(named name: String) {
        thumbnailCache.removeObject(forKey: name as NSString)
        let url = blobURL(named: name)
        io.async { try? FileManager.default.removeItem(at: url) }
    }

    func waitUntilLoaded() async {
        guard isLoading else { return }
        await withCheckedContinuation { loadedWaiters.append($0) }
    }

    /// An asynchronous barrier for termination and persistence tests.
    func flush() async {
        await waitUntilLoaded()
        await withCheckedContinuation { continuation in
            io.async { continuation.resume() }
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
        releaseFileAccess(fileAccess.removeValue(forKey: entry.id) ?? [])
        for name in blobNames(for: entry) {
            removeBlob(named: name)
        }
    }

    nonisolated private static func loadHistory(metadata: URL, blobs: URL) -> [ClipboardEntry] {
        let entries: [ClipboardEntry]
        if FileManager.default.fileExists(atPath: metadata.path) {
            do {
                entries = try JSONDecoder().decode([ClipboardEntry].self, from: Data(contentsOf: metadata))
            } catch {
                // Preserve both metadata and blobs after a decoding failure.
                print("[ClipboardStore] Failed to load clipboard history: \(error)")
                return []
            }
        } else {
            entries = []
        }
        let referenced = Set(entries.flatMap { entry -> [String] in
            var names = [String]()
            if case .image(let name, _, _) = entry.content { names.append(name) }
            if let name = entry.thumbnailFileName { names.append(name) }
            return names
        })
        if let contents = try? FileManager.default.contentsOfDirectory(at: blobs, includingPropertiesForKeys: nil) {
            for url in contents where !referenced.contains(url.lastPathComponent) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return entries
    }

    private func finishLoading(_ loaded: [ClipboardEntry]) {
        let mutations = pendingMutations
        pendingMutations.removeAll()
        isLoading = false
        isReplaying = true
        entries = loaded
        for mutation in mutations {
            switch mutation {
            case .add(let entry): add(entry)
            case .move(let id, let date): moveToTop(id: id, at: date)
            case .thumbnail(let name, let id): setThumbnail(name, forEntry: id)
            case .delete(let id): delete(id: id)
            case .clear: clearAll()
            }
        }
        evict()
        isReplaying = false
        if !mutations.isEmpty || entries.count != loaded.count { save() }
        let waiters = loadedWaiters
        loadedWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    private func save() {
        guard !isLoading, !isReplaying else { return }
        let snapshot = entries
        let url = metadataURL
        io.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[ClipboardStore] Failed to save clipboard history: \(error)")
            }
        }
    }
}
