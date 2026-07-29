//
//  MultilineTextEditor.swift
//  MiniMe
//

import SwiftUI

/// A bordered, genuinely multi-line text input with placeholder text.
///
/// `TextField(axis: .vertical)` is not usable for this on macOS: it renders one line
/// tall regardless of `lineLimit`, and Return submits the field instead of inserting a
/// newline. `TextEditor` is a real text view, so it accepts Return — this wraps it with
/// the border and placeholder a `TextField` would have given us for free.
struct MultilineTextEditor: View {
    /// Describes the field for VoiceOver, since `TextEditor` carries no label of its own.
    let label: String
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 92

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        TextEditor(text: $text)
            // Labelled here rather than on the composite below, so the label lands on the
            // text area itself instead of being merged across the border/placeholder overlays.
            .accessibilityLabel(label)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .frame(height: height)
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor))
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                        // Decorative — the text area above carries the real label.
                        .accessibilityHidden(true)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .accessibilityLabel(label)
    }
}
