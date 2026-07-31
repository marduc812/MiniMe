//
//  ClipboardTextKindCache.swift
//  MiniMe
//

import Foundation

/// Memoises `ClipboardEntry.textKind`, keyed by entry id.
///
/// Classification runs a JSON parse and `NSDataDetector` — measured at ~0.7 ms
/// per entry in a release build — and `ClipboardRow` needs it to choose its
/// icon. Rows redraw whenever the hovered row changes, so an uncached lookup
/// charges that cost for every visible row on every mouse move, which is what
/// makes a long history feel sticky under the cursor.
///
/// An entry's content is immutable once created, so a result keyed by its id can
/// never go stale.
@MainActor
enum ClipboardTextKindCache {
    /// Well above the largest history so a full list never evicts itself, and
    /// small enough that the retained enums are irrelevant in memory.
    private static let capacity = 1_000

    private static var cache: [UUID: ClipboardTextKind] = [:]

    static func kind(for entry: ClipboardEntry) -> ClipboardTextKind {
        if let cached = cache[entry.id] { return cached }
        // Refilling costs the same as the first fill and only happens after a
        // thousand distinct entries, so dropping everything is a fine way to
        // bound this — no per-id bookkeeping to keep in sync with the store.
        if cache.count >= capacity { cache.removeAll(keepingCapacity: true) }
        let kind = entry.textKind
        cache[entry.id] = kind
        return kind
    }
}
