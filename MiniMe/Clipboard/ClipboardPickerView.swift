//
//  ClipboardPickerView.swift
//  MiniMe
//

import SwiftUI

struct ClipboardPickerView: View {
    @ObservedObject var store: ClipboardStore
    let isEnabled: Bool
    let onSelect: (ClipboardEntry) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @State private var searchText = ""
    @State private var selectedID: UUID?
    @State private var hoveredID: UUID?
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    private static let listWidth: CGFloat = 292

    private var filteredEntries: [ClipboardEntry] {
        store.entries.filter { $0.matches(query: searchText) }
    }

    /// The entry shown in the detail pane: hover wins so mousing over the list
    /// previews instantly, otherwise the keyboard selection.
    private var previewEntry: ClipboardEntry? {
        let visible = filteredEntries
        if let hoveredID, let entry = visible.first(where: { $0.id == hoveredID }) {
            return entry
        }
        if let selectedID, let entry = visible.first(where: { $0.id == selectedID }) {
            return entry
        }
        return visible.first
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider().opacity(0.5)

            if !isEnabled {
                disabledState
            } else if filteredEntries.isEmpty {
                emptyState
            } else {
                splitContent
            }

            if !store.entries.isEmpty {
                Divider().opacity(0.5)
                footer
            }
        }
        .frame(
            width: ClipboardPanelController.panelSize.width,
            height: ClipboardPanelController.panelSize.height
        )
        .background {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        // Links in the preview open in the browser and dismiss the picker: the
        // panel floats at pop-up-menu level, so leaving it up would park it on
        // top of the page the user just asked for.
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            onClose()
            return .handled
        })
        .onAppear {
            searchFocused = true
            selectedID = filteredEntries.first?.id
            installKeyMonitor()
        }
        .onDisappear(perform: removeKeyMonitor)
        .onChange(of: searchText) { _, _ in
            // Keep the highlight on a row that is actually visible.
            selectedID = filteredEntries.first?.id
            hoveredID = nil
        }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 13))
            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            Text("\(store.entries.count)")
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.4), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var splitContent: some View {
        HStack(spacing: 0) {
            list
                .frame(width: Self.listWidth)

            Divider().opacity(0.5)

            ClipboardDetailView(
                entry: previewEntry,
                store: store,
                onCopy: { onSelect($0) },
                onDelete: { delete($0) }
            )
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                        ClipboardRow(
                            entry: entry,
                            store: store,
                            shortcutIndex: index < 9 ? index + 1 : nil,
                            isSelected: entry.id == selectedID,
                            onSelect: { onSelect(entry) },
                            onDelete: { delete(entry) },
                            onHoverChange: { hovering in
                                if hovering {
                                    hoveredID = entry.id
                                } else if hoveredID == entry.id {
                                    hoveredID = nil
                                }
                            }
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
            }
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            if searchText.isEmpty {
                Text("κ")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.35))
                Text("No clipboard history yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Anything you copy will show up here")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.tertiary)
                Text("No matches found")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var disabledState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "pause.circle")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Clipboard history is turned off")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Button("Open Clipboard Settings", action: onOpenSettings)
                .buttonStyle(.link)
                .font(.system(size: 11))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("↑↓ move · ↩ paste · ⌘1–9 quick paste · esc close")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                store.clearAll()
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Mutation

    private func delete(_ entry: ClipboardEntry) {
        let visible = filteredEntries
        // Move the highlight to a neighbour before the row disappears.
        if selectedID == entry.id,
           let index = visible.firstIndex(where: { $0.id == entry.id }) {
            let remaining = visible.filter { $0.id != entry.id }
            selectedID = remaining.indices.contains(index) ? remaining[index].id : remaining.last?.id
        }
        if hoveredID == entry.id { hoveredID = nil }
        store.delete(id: entry.id)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let visible = filteredEntries

        if event.modifierFlags.contains(.command),
           let characters = event.charactersIgnoringModifiers,
           let digit = Int(characters),
           (1...9).contains(digit) {
            if visible.indices.contains(digit - 1) {
                onSelect(visible[digit - 1])
            }
            return true
        }

        switch event.keyCode {
        case 126: // up
            moveSelection(by: -1, in: visible)
            return true
        case 125: // down
            moveSelection(by: 1, in: visible)
            return true
        case 36, 76: // return, enter
            if let id = selectedID, let entry = visible.first(where: { $0.id == id }) {
                onSelect(entry)
            }
            return true
        case 53: // escape
            onClose()
            return true
        default:
            return false
        }
    }

    private func moveSelection(by offset: Int, in visible: [ClipboardEntry]) {
        guard !visible.isEmpty else { return }
        let current = selectedID.flatMap { id in visible.firstIndex { $0.id == id } } ?? -1
        let next = min(max(current + offset, 0), visible.count - 1)
        selectedID = visible[next].id
        // Keyboard navigation takes over the preview from any stale hover.
        hoveredID = nil
    }
}

#if DEBUG
private extension ClipboardStore {
    /// Store seeded with representative entries, backed by a throwaway temp
    /// directory so previews never touch real clipboard history.
    static func mock() -> ClipboardStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniMePreview-\(UUID().uuidString)", isDirectory: true)
        let store = ClipboardStore(directory: directory, maxEntries: 200)

        store.add(ClipboardEntry(
            content: .text("https://developer.apple.com/documentation/swiftui/scrollviewreader"),
            timestamp: Date().addingTimeInterval(-30),
            sourceAppName: "Safari",
            sourceAppBundleID: "com.apple.Safari"
        ))
        store.add(ClipboardEntry(
            content: .text("""
                Fix the flaky ClipboardStoreTests by seeding a fresh temp \
                directory per test instead of sharing Application Support.
                """),
            timestamp: Date().addingTimeInterval(-60 * 12),
            sourceAppName: "Xcode",
            sourceAppBundleID: "com.apple.dt.Xcode"
        ))
        store.add(ClipboardEntry(
            content: .image(fileName: "preview-image.png", pixelWidth: 1920, pixelHeight: 1080),
            timestamp: Date().addingTimeInterval(-60 * 60 * 2),
            sourceAppName: "Preview",
            sourceAppBundleID: "com.apple.Preview"
        ))
        store.add(ClipboardEntry(
            content: .files(paths: ["/Users/marduc812/Downloads/invoice.pdf"]),
            timestamp: Date().addingTimeInterval(-60 * 60 * 5),
            sourceAppName: "Finder",
            sourceAppBundleID: "com.apple.finder"
        ))
        store.add(ClipboardEntry(
            content: .files(paths: ["/tmp/does-not-exist/report.key"]),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 3),
            sourceAppName: "Finder",
            sourceAppBundleID: "com.apple.finder"
        ))
        store.add(ClipboardEntry(
            content: .text(#"{"id": 7, "tags": ["ocr", "clipboard"], "enabled": true}"#),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 4),
            sourceAppName: "Xcode",
            sourceAppBundleID: "com.apple.dt.Xcode"
        ))
        store.add(ClipboardEntry(
            content: .text("marduc812@gmail.com"),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 6)
        ))
        store.add(ClipboardEntry(
            content: .text("550e8400-e29b-41d4-a716-446655440000"),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 8)
        ))
        store.add(ClipboardEntry(
            content: .text("#FF8800"),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 10)
        ))
        store.add(ClipboardEntry(
            content: .text("2026-07-29T10:15:30Z"),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 12)
        ))
        store.add(ClipboardEntry(
            content: .text("kimeno"),
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 30 * 2)
        ))

        return store
    }
}

#Preview("Populated") {
    ClipboardPickerView(
        store: .mock(),
        isEnabled: true,
        onSelect: { _ in },
        onClose: {},
        onOpenSettings: {}
    )
}

#Preview("Empty") {
    ClipboardPickerView(
        store: ClipboardStore(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("MiniMePreview-\(UUID().uuidString)", isDirectory: true)
        ),
        isEnabled: true,
        onSelect: { _ in },
        onClose: {},
        onOpenSettings: {}
    )
}

#Preview("Disabled") {
    ClipboardPickerView(
        store: .mock(),
        isEnabled: false,
        onSelect: { _ in },
        onClose: {},
        onOpenSettings: {}
    )
}
#endif
