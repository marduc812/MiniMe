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
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    private var filteredEntries: [ClipboardEntry] {
        store.entries.filter { $0.matches(query: searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar

            Divider().opacity(0.5).padding(.horizontal, 12)

            if !isEnabled {
                disabledState
            } else if filteredEntries.isEmpty {
                emptyState
            } else {
                list
            }

            if !store.entries.isEmpty {
                Divider().opacity(0.5).padding(.horizontal, 12)
                footer
            }
        }
        .frame(width: 460, height: 520)
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
        .onAppear {
            searchFocused = true
            selectedID = filteredEntries.first?.id
            installKeyMonitor()
        }
        .onDisappear(perform: removeKeyMonitor)
        .onChange(of: searchText) { _, _ in
            // Keep the highlight on a row that is actually visible.
            selectedID = filteredEntries.first?.id
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            Text("Clipboard")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(store.entries.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))
            TextField("Search…", text: $searchText)
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
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                        ClipboardRow(
                            entry: entry,
                            store: store,
                            shortcutIndex: index < 9 ? index + 1 : nil,
                            isSelected: entry.id == selectedID,
                            onSelect: { onSelect(entry) },
                            onDelete: { store.delete(id: entry.id) }
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
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
            Text("⌘1–9 to paste · ↑↓ to move · esc to close")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
    }
}
