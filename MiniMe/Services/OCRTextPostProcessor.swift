//
//  OCRTextPostProcessor.swift
//  MiniMe
//
//  Pure text cleanup applied after recognition and line ordering. Conservative
//  by design: it fixes obvious OCR/layout artifacts (soft line-wrap hyphens,
//  trailing whitespace, excess blank lines) without touching the content of the
//  recognized words.
//

import Foundation

enum OCRTextPostProcessor {

    /// Cleans up recognized text. Idempotent on already-clean input.
    static func clean(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")

        // Strip trailing whitespace from every line.
        lines = lines.map { line in
            String(line.reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
        }

        // De-hyphenate soft line wraps: a line ending in "<letter>-" whose next
        // line begins with a lowercase letter is almost always one word split
        // across the wrap. A capitalized or non-letter continuation is left
        // alone (likely a genuine hyphenated compound or list).
        var merged: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if index + 1 < lines.count,
               let joined = softWrapJoin(line, lines[index + 1]) {
                lines[index + 1] = joined
                index += 1
                continue
            }
            merged.append(line)
            index += 1
        }

        var result = merged.joined(separator: "\n")

        // Collapse runs of 3+ newlines (2+ blank lines) down to a single blank line.
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the merged word if `line`/`next` form a soft-wrapped hyphenation,
    /// otherwise nil.
    private static func softWrapJoin(_ line: String, _ next: String) -> String? {
        guard line.hasSuffix("-"),
              let beforeHyphen = line.dropLast().last,
              beforeHyphen.isLetter,
              let firstOfNext = next.first,
              firstOfNext.isLetter,
              firstOfNext.isLowercase else {
            return nil
        }
        return String(line.dropLast()) + next
    }
}
