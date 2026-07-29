//
//  ClipboardTextKind.swift
//  MiniMe
//

import Foundation

/// What a text clipping actually *is*, when the whole clipping is one thing —
/// a link, an email address, a JSON payload, a date, a hex value, a UUID.
///
/// Detection is deliberately whole-string only: a paragraph that happens to
/// mention a URL is still prose, and giving it a link icon would be a lie. The
/// checks are ordered cheapest-first and every branch is length-capped, because
/// this runs while rendering clipboard rows.
enum ClipboardTextKind: Equatable {
    case plain
    case link(URL)
    /// A `mailto:` URL built from a bare address.
    case email(URL)
    case json
    case date
    case hex
    case uuid

    var symbolName: String {
        switch self {
        case .plain: return "text.alignleft"
        case .link:  return "link"
        case .email: return "envelope"
        case .json:  return "curlybraces"
        case .date:  return "calendar"
        case .hex:   return "number"
        case .uuid:  return "barcode"
        }
    }

    /// The target to open when the entry is something openable.
    var url: URL? {
        switch self {
        case .link(let url), .email(let url): return url
        default: return nil
        }
    }

    /// Classification is a nicety; redrawing the list is not. This runs on every
    /// row redraw, so the scan is capped short enough that the worst case stays
    /// trivial. Links, addresses, dates, and identifiers are all far below it;
    /// only an oversized JSON payload loses its icon, which is a fair trade.
    private static let maxLength = 2_048

    static func detect(in string: String) -> ClipboardTextKind {
        guard string.count <= maxLength else { return .plain }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }

        if isJSON(trimmed) { return .json }
        if isUUID(trimmed) { return .uuid }
        if isHex(trimmed) { return .hex }
        return dataDetectorKind(for: trimmed)
    }

    // MARK: - Structural checks

    /// Only objects and arrays count. A bare `123` or `"string"` is valid JSON
    /// to a parser but nobody thinks of it as a JSON clipping.
    private static func isJSON(_ trimmed: String) -> Bool {
        guard let first = trimmed.first, first == "{" || first == "[" else { return false }
        guard let last = trimmed.last, last == "}" || last == "]" else { return false }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func isUUID(_ trimmed: String) -> Bool {
        trimmed.count == 36 && UUID(uuidString: trimmed) != nil
    }

    /// `#rgb` / `#rrggbb` / `#rrggbbaa` colours, `0x`-prefixed numbers, and bare
    /// digests. Bare runs need a letter and some length, otherwise every order
    /// number and PIN in the history turns into a hex clipping.
    private static func isHex(_ trimmed: String) -> Bool {
        guard trimmed.count <= 128 else { return false }

        if trimmed.hasPrefix("#") {
            let digits = trimmed.dropFirst()
            return [3, 4, 6, 8].contains(digits.count) && digits.allSatisfy(\.isHexDigit)
        }

        if trimmed.count > 2, trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            return trimmed.dropFirst(2).allSatisfy(\.isHexDigit)
        }

        return trimmed.count >= 8
            && trimmed.allSatisfy(\.isHexDigit)
            && trimmed.contains { $0.isLetter }
    }

    // MARK: - Detector-backed checks

    /// Links, emails, and natural-language dates all come from `NSDataDetector`,
    /// the expensive path — kept in bounds by `maxLength`.
    private static func dataDetectorKind(for trimmed: String) -> ClipboardTextKind {
        if isISOTimestamp(trimmed) { return .date }
        guard let detector else { return .plain }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let matches = detector.matches(in: trimmed, range: range)
        // A single match covering the entire string, or it is mixed content.
        guard matches.count == 1, let match = matches.first, match.range == range else { return .plain }

        switch match.resultType {
        case .link:
            guard let url = match.url else { return .plain }
            return url.scheme == "mailto" ? .email(url) : .link(url)
        case .date:
            // "2026" parses as a date; a lone year is a number in practice.
            return trimmed.count >= 6 ? .date : .plain
        default:
            return .plain
        }
    }

    private static func isISOTimestamp(_ trimmed: String) -> Bool {
        guard (20...35).contains(trimmed.count), trimmed.contains("T") else { return false }
        return isoFormatter.date(from: trimmed) != nil
            || isoFractionalFormatter.date(from: trimmed) != nil
    }

    // NSRegularExpression (and so NSDataDetector) is documented as thread-safe
    // for matching, and the formatters are only read, so sharing them is safe.
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
            | NSTextCheckingResult.CheckingType.date.rawValue
    )

    private static let isoFormatter = ISO8601DateFormatter()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension ClipboardEntry {
    /// What this entry is, for icon and preview purposes. Images and files carry
    /// their own icons already, so only text is classified.
    var textKind: ClipboardTextKind {
        guard case .text(let string) = content else { return .plain }
        return ClipboardTextKind.detect(in: string)
    }
}
