//
//  ClipboardPreviewText.swift
//  MiniMe
//

import Foundation

/// How much of a text clipping the detail pane is allowed to lay out.
///
/// SwiftUI measures a `Text` inside a `ScrollView` against an unbounded height,
/// so the whole string is typeset in one synchronous pass on the main thread.
/// That is fine for a clipping and fatal for a dump: a 56k-character terminal
/// capture took 3.3 s to measure, all of it inside `boundingRectWithSize:` —
/// long enough to spin the cursor every time the picker opened on it.
///
/// Most of that cost is not the length. The capture was full of box-drawing and
/// block glyphs (`─`, `│`, `⎿`, `■`), none of which live in the system font, so
/// CoreText ran its font cascade looking for fallbacks — stripping the clipping
/// to ASCII at the same length cut the measurement from 3284 ms to 480 ms. A
/// length cap is the lever that works for both, since it bounds the number of
/// characters the cascade can be asked about.
///
/// This is the same bargain `ClipboardTextKind.maxLength` and
/// `LinkedTextView.maxScanLength` already strike, extended from *analysing* the
/// clipping to *drawing* it. Nothing is lost: Copy still puts the full clipping
/// on the pasteboard, and the pane says how much it is not showing.
enum ClipboardPreviewText {

    /// Measured against the clipping that caused the hang: ~26 ms at 2k
    /// characters, ~73 ms at 4k, ~116 ms at 5k, ~220 ms at 8k. The pane is
    /// rebuilt on every hover, so this stays low enough that running the list
    /// with the pointer never stutters.
    static let maxLength = 4_000

    struct Preview: Equatable {
        /// The text to draw — the whole clipping, or its first `maxLength` characters.
        let text: String
        /// How many characters were left out, for the pane to report.
        let omittedCharacters: Int

        var isTruncated: Bool { omittedCharacters > 0 }
    }

    /// The drawable head of `string`, cut on a character boundary so a
    /// multi-scalar grapheme at the limit is never split into a broken glyph.
    static func preview(for string: String) -> Preview {
        let count = string.count
        guard count > maxLength else {
            return Preview(text: string, omittedCharacters: 0)
        }
        return Preview(
            text: String(string.prefix(maxLength)),
            omittedCharacters: count - maxLength
        )
    }
}
