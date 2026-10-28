import AppKit

/// Polls clipboard metadata on the UI thread. Data acquisition and image work
/// happen in a separate process, so an unresponsive provider cannot freeze us.
@MainActor
final class ClipboardMonitor: ObservableObject {
    static let pollInterval: TimeInterval = 0.5
    static let maxImageBytes = ClipboardReadWorker.maxImageBytes

    var captureImagesAndFiles = true {
        didSet { if captureImagesAndFiles != oldValue { revision += 1 } }
    }
    var ignoreConcealed = true {
        didSet { if ignoreConcealed != oldValue { revision += 1 } }
    }

    private let store: ClipboardStore
    private let pasteboard: NSPasteboard
    private let reader: any ClipboardReading
    private var timer: Timer?
    private var lastChangeCount: Int
    private var revision = 0
    private var isReading = false

    init(store: ClipboardStore, pasteboard: NSPasteboard = .general,
         reader: any ClipboardReading = ClipboardReadService()) {
        self.store = store
        self.pasteboard = pasteboard
        self.reader = reader
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        revision += 1
    }

    /// Invalidates an outstanding read as well as suppressing our own write.
    func acknowledgeSelfWrite() {
        revision += 1
        lastChangeCount = pasteboard.changeCount
    }

    func poll() async {
        guard !isReading else { return }
        isReading = true
        let capturedRevision = revision
        defer { isReading = false }
        await store.waitUntilLoaded()
        guard capturedRevision == revision else { return }
        // changeCount does not ask another app to fulfill promised clipboard data.
        let requestedChangeCount = pasteboard.changeCount
        guard requestedChangeCount != lastChangeCount else { return }
        let response = await reader.read(ClipboardReadRequest(
            pasteboardName: pasteboard.name.rawValue,
            afterChangeCount: lastChangeCount,
            captureImagesAndFiles: captureImagesAndFiles,
            ignoreConcealed: ignoreConcealed
        ))
        guard capturedRevision == revision else { return }
        guard let response else {
            // Do not repeatedly launch workers against the same stalled provider.
            lastChangeCount = requestedChangeCount
            return
        }
        lastChangeCount = response.changeCount
        guard pasteboard.changeCount == response.changeCount,
              let entry = response.entry else { return }

        // File writes use the store's ordered I/O queue. Recheck after awaiting
        // a blob write because the clipboard or settings may have changed.
        if case .image(let name, _, _) = entry.content {
            guard let data = response.imageData,
                  await store.writeBlob(data, named: name) else { return }
            guard capturedRevision == revision, pasteboard.changeCount == response.changeCount else {
                store.removeBlob(named: name)
                return
            }
        }
        let access = await store.resolveFileAccess(response.fileBookmarks ?? [])
        guard capturedRevision == revision, pasteboard.changeCount == response.changeCount else {
            store.releaseFileAccess(access)
            if case .image(let name, _, _) = entry.content { store.removeBlob(named: name) }
            return
        }
        let stored = store.add(entry)
        store.retainFileAccess(access, forEntry: stored.id)
        if let data = response.thumbnailData {
            let name = "\(stored.id.uuidString)-thumb.png"
            if await store.writeBlob(data, named: name) {
                if store.entries.contains(where: { $0.id == stored.id }) {
                    store.setThumbnail(name, forEntry: stored.id)
                } else {
                    store.removeBlob(named: name)
                }
            }
        }
    }
}
