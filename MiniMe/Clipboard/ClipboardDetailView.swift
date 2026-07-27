//
//  ClipboardDetailView.swift
//  MiniMe
//

import SwiftUI

/// Right-hand pane of the clipboard picker: a full preview of the selected
/// entry (complete text, full-size image, file listing) plus its metadata
/// and Copy / Delete actions.
struct ClipboardDetailView: View {
    let entry: ClipboardEntry?
    let store: ClipboardStore
    let onCopy: (ClipboardEntry) -> Void
    let onDelete: (ClipboardEntry) -> Void

    var body: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 12) {
                previewCard(for: entry)
                metadata(for: entry)
                actions(for: entry)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            placeholder
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private func previewCard(for entry: ClipboardEntry) -> some View {
        Group {
            switch entry.content {
            case .text(let string):
                textPreview(string)
            case .image(let fileName, _, _):
                ImageBlobView(url: store.blobURL(named: fileName))
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .files(let paths):
                filesPreview(paths)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func textPreview(_ string: String) -> some View {
        ScrollView {
            Text(string)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private func filesPreview(_ paths: [String]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(paths, id: \.self) { path in
                    fileRow(path)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fileRow(_ path: String) -> some View {
        let exists = FileManager.default.fileExists(atPath: path)
        return HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text((path as NSString).lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(exists ? (path as NSString).deletingLastPathComponent : "File no longer available")
                    .font(.system(size: 10))
                    .foregroundStyle(exists ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.orange))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .opacity(exists ? 1 : 0.6)
        .padding(6)
    }

    // MARK: - Metadata

    private func metadata(for entry: ClipboardEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            if entry.sourceAppName != nil || entry.sourceAppBundleID != nil {
                GridRow {
                    metadataLabel("Source")
                    HStack(spacing: 5) {
                        if let icon = ClipboardIconResolver.appIcon(
                            bundleID: entry.sourceAppBundleID,
                            name: entry.sourceAppName
                        ) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 13, height: 13)
                        }
                        Text(entry.sourceAppName ?? "Unknown")
                    }
                }
            }

            GridRow {
                metadataLabel("Copied")
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
            }

            GridRow {
                metadataLabel(contentLabel(for: entry.content))
                Text(contentValue(for: entry.content))
            }
        }
        .font(.system(size: 11))
    }

    private func metadataLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.tertiary)
            .gridColumnAlignment(.leading)
    }

    private func contentLabel(for content: ClipboardContent) -> String {
        switch content {
        case .text:  return "Length"
        case .image: return "Size"
        case .files: return "Files"
        }
    }

    private func contentValue(for content: ClipboardContent) -> String {
        switch content {
        case .text(let string):
            let characters = string.count.formatted()
            let lines = string.components(separatedBy: .newlines).count
            return lines > 1 ? "\(characters) characters · \(lines) lines" : "\(characters) characters"
        case .image(_, let width, let height):
            return "\(width) × \(height) px"
        case .files(let paths):
            return paths.count == 1 ? "1 file" : "\(paths.count) files"
        }
    }

    // MARK: - Actions

    private func actions(for entry: ClipboardEntry) -> some View {
        HStack {
            Button {
                onCopy(entry)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()

            Button(role: .destructive) {
                onDelete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 30, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("Select an item to preview")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loads the full-resolution image blob off the main thread so hovering
/// through large image entries never stutters the picker.
private struct ImageBlobView: View {
    let url: URL

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 26, weight: .thin))
                    .foregroundStyle(.quaternary)
            }
        }
        .task(id: url) {
            let data = await Task.detached { try? Data(contentsOf: url) }.value
            image = data.flatMap(NSImage.init(data:))
        }
    }
}
