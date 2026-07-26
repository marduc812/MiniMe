# Clipboard Manager — Design

**Date:** 2026-07-26
**Status:** Approved, ready for implementation planning

## Summary

Add a clipboard history manager to MiniMe. A global hotkey (default ⌥C) opens a
centered picker panel listing recent clipboard entries. The user searches,
navigates, and selects an entry; MiniMe writes it back to the clipboard and —
depending on a setting — reactivates the previously frontmost app and pastes it.

Clipboard entries capture text, images, and file references. Each records the
app it was copied from, when it was copied, and a preview appropriate to its
kind.

This is a separate subsystem from the existing OCR capture history. The existing
`CaptureHistoryStore` and its window are unchanged.

## Goals

- Capture every clipboard change (text, image, files) with source app and timestamp.
- Fast keyboard-driven retrieval: hotkey → type to search → ⌘1–9 or ↑↓⏎ to pick.
- Preview every entry meaningfully — text snippet, image thumbnail, real file preview.
- User-configurable behavior on pick: copy-and-paste, or copy only.
- Never capture secrets that apps have explicitly flagged as sensitive.

## Non-goals

- Pinned/favorite clips.
- Syncing history across machines.
- Rich text / RTF fidelity — text entries are stored as plain strings.
- Editing an entry before pasting.
- Capturing pasteboards other than `NSPasteboard.general`.

---

## 1. Data model

### `ClipboardEntry`

```swift
enum ClipboardContent: Codable, Hashable {
    case text(String)
    case image(fileName: String, pixelWidth: Int, pixelHeight: Int)
    case files(paths: [String])
}

struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let content: ClipboardContent
    let title: String
    let timestamp: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?
    let thumbnailFileName: String?
}
```

Swift synthesizes `Codable` for enums with associated values, so
`ClipboardContent` needs no hand-written coding. File URLs are stored as
`String` paths rather than `URL` to keep the JSON stable and readable.

`fileName` and `thumbnailFileName` are bare file names, not paths — they are
resolved against the blob directory at read time. Storing bare names means the
container path can change (OS migration, app rename) without invalidating the
store.

### Title generation

| Content | Title |
|---|---|
| text | First non-empty line, trimmed, truncated to 50 chars with `...`; `"Untitled"` if blank |
| image | `"Image 1290×800"` |
| files (one) | The file's last path component, e.g. `"interview-take-3.m4a"` |
| files (many) | `"3 files"` |

This mirrors `CaptureEntry.generateTitle` for the text case.

### Search

An entry matches a query if the query is a case-insensitive substring of:

- its `title`, **or**
- its full text (text entries only), **or**
- any of its file paths' last path components (file entries only).

Image entries are matchable by title only.

---

## 2. Storage

### Location

```
<Application Support>/MiniMe/
  clipboard.json                  # array of ClipboardEntry
  ClipboardBlobs/
    <uuid>.png                    # full-size image for image entries
    <uuid>-thumb.png              # cached thumbnail for image and file entries
```

`Application Support` is resolved via
`FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask)`,
which inside the App Sandbox lands in the app's container. The `MiniMe/` and
`ClipboardBlobs/` directories are created on first use.

### Why not UserDefaults

The existing `CaptureHistoryStore` persists to UserDefaults, which is fine for
100 short OCR strings. 200 clipboard entries including image blobs would be tens
of megabytes; UserDefaults is loaded wholesale into memory and rewritten on every
change, so this store uses files instead.

### Write policy

`clipboard.json` is rewritten on every mutation (add, delete, clear, evict).
Writes are atomic (`Data.write(to:options: .atomic)`). At 200 entries of metadata
this is a small write and does not need debouncing.

### Limit and eviction

**Maximum 200 entries.** Chosen as roughly a week of heavy copying while keeping
the on-disk store in the low tens of megabytes given the per-image cap below.
Configurable in settings to 50 / 100 / 200 / 500.

When the store exceeds the limit, the oldest entries are dropped and **their blob
files are deleted**. Lowering the limit in settings evicts immediately.

On launch the store performs one **orphan sweep**: any file in `ClipboardBlobs/`
not referenced by a loaded entry is deleted. This recovers space after a crash
between blob write and metadata write.

If `clipboard.json` fails to decode, the store starts empty and logs — it does
not crash and does not delete the file.

### Image size cap

Images whose PNG representation exceeds **25 MB** are not captured at all. This
avoids a single large copy dominating the store. No user-visible error; the copy
simply does not appear in history.

---

## 3. Capture — `ClipboardMonitor`

macOS provides no clipboard-change notification, so the monitor polls
`NSPasteboard.general.changeCount` on a **0.5 s** repeating timer. The timer runs
only while clipboard history is enabled in settings.

### Read order

On a detected change, read in this priority order and stop at the first match:

1. **Files** — `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`
2. **Image** — `readObjects(forClasses: [NSImage.self], options: nil)`
3. **Text** — `string(forType: .string)`

Files come first because a Finder file copy also places a text representation on
the pasteboard; without ordering, file copies would be recorded as text. Images
come before text for the same reason.

If none match, or the text is empty/whitespace-only, nothing is recorded.

### Source app

`NSWorkspace.shared.frontmostApplication` at the moment the change is detected,
storing both `localizedName` and `bundleIdentifier`. MiniMe is a menu-bar app and
is not frontmost during normal use, so this correctly attributes the copy to the
user's app.

`bundleIdentifier` is stored because it is a more reliable key for icon lookup
than the localized name — the existing `CaptureRow.appIcon(for:)` matches on
`localizedName` and falls back to guessing a path in `/Applications`, which is
fragile. New clipboard rows resolve icons by bundle identifier via
`NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`, falling back to
the name-based lookup for entries with no bundle ID.

### Self-writes

When MiniMe itself writes to the pasteboard (picking an entry, or the existing
OCR auto-copy), the monitor records the new `changeCount` as already-seen so the
write is not re-ingested as a fresh entry.

### Sensitive content

Before reading, check `NSPasteboard.general.types` for any of:

- `org.nspasteboard.ConcealedType`
- `org.nspasteboard.TransientType`
- `org.nspasteboard.AutoGeneratedType`

These are the conventional markers password managers and generators use to say
"do not persist this." If any is present the change is skipped entirely. Governed
by the *Ignore password-manager clipboard* setting, **on by default**.

### Deduplication

On add, the store searches **the whole history** — not just the newest entry —
for an entry with equal content. If one is found it is moved to position 0 and
its timestamp refreshed, rather than a duplicate being appended. Equality is by
content value: same string for text, same ordered path list for files.

Images are never deduplicated — comparing pixel data on every clipboard change is
not worth the cost — so re-copying the same image produces a second entry.

---

## 4. Thumbnails — `ClipboardThumbnailer`

**Thumbnails are generated at capture time and cached to disk. They are never
generated lazily at display time.**

This is a sandbox requirement, not an optimization. The App Sandbox grants read
access to file URLs read from the pasteboard only at read time. Once the app
restarts, a stored path is an ordinary string with no associated permission, and
generating a preview from it would fail. Capturing the preview up front is the
only way file entries keep working across launches.

### For image entries

Downsample the `NSImage` to fit 240×240 points and write as PNG. The full-size
PNG is written alongside it for pasting.

### For file entries

Use `QLThumbnailGenerator` (QuickLookThumbnailing) at 240×240, requesting
`.thumbnail` representation with `.icon` as fallback. This yields:

- real content previews for images, PDFs (first page), and video (a frame)
- the system type icon for everything else — which is already the correct
  behavior for audio (waveform icon), archives, apps, source files, and so on

If QuickLook returns nothing, fall back to
`NSWorkspace.shared.icon(forFile:)` and write that as the thumbnail.

For a multi-file copy, thumbnail the **first** file only; the row shows that
thumbnail with a "3 files" title.

Thumbnail generation is asynchronous. The entry is inserted immediately with
`thumbnailFileName == nil` and updated when generation completes, so the picker
never blocks on it.

### Missing files

At display time, a file entry whose paths no longer exist renders dimmed with the
caption *"File no longer available."* Its cached thumbnail is still shown — it
was captured while the file existed. Selecting such an entry is a no-op with a
brief inline message rather than writing a dead URL to the pasteboard.

---

## 5. The picker panel

### Window

A borderless `KeyablePanel`, constructed the same way as the existing history
panel in `CaptureHistoryStore.showHistoryWindow()`:

```swift
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.level = .popUpMenu
panel.isOpaque = false
panel.backgroundColor = .clear
panel.isFloatingPanel = true
panel.becomesKeyOnlyIfNeeded = false
```

**Size:** 460 × 520.

**Position:** centered on the screen the user is currently working on. In a
multi-monitor setup the panel must never appear on a different display from the
one the user is looking at.

The active screen is resolved by `ActiveScreenResolver`:

1. The screen whose `frame` contains `NSEvent.mouseLocation`.
2. Failing that, the screen **nearest** to the mouse, by squared distance from
   the point to the rect.

Step 1 alone is not sufficient. `CGRect.contains` excludes the `maxX`/`maxY`
edges, so a cursor pushed hard against the top or right edge of a display can
match no screen at all; the same holds in the dead coordinate space beside a
smaller display in an offset arrangement. The common
`first(where:) ?? NSScreen.main` idiom returns `nil` in exactly those cases and
falls back to the wrong display.

Nearest-by-distance is used rather than `NSScreen.main` because `NSScreen.main`
means "the screen with the key window," which for a menu-bar-only app like MiniMe
is unreliable. Distance always resolves to the display the cursor is closest to,
which is the one the user is working on. It is also a pure function of a point
and a list of rects, so it is unit-testable without a real multi-monitor rig.

Centering uses the resolved screen's `visibleFrame`, not `frame`, so the panel
is centered within usable space and never sits under the menu bar or Dock. The
final rect is clamped to `visibleFrame` so an oversized panel on a small display
stays fully on-screen.

The picker is repositioned every time it opens — the user may have moved to a
different display since the last invocation.

Visual treatment matches `HistoryView`: `VisualEffectView(material: .hudWindow)`
background, 14 pt continuous corner radius, hairline white border, layered
shadows.

**Activation order matters.** The controller captures
`NSWorkspace.shared.frontmostApplication` *before* calling
`NSApp.activate(ignoringOtherApps:)` and `makeKey()` on the panel — otherwise the
app it needs to paste back into would already have been displaced by MiniMe
itself.

A global click-outside monitor closes the panel, matching the history window's
behavior.

### Layout

```
┌──────────────────────────────────────────┐
│ 🔍  Search…                          200 │
├──────────────────────────────────────────┤
│ ⌘1  git push origin main                 │
│     Terminal · 2 min                     │
│ ⌘2  [▨]  Image 1290×800                  │
│     Safari · 15 min                      │
│ ⌘3  [♪]  interview-take-3.m4a            │
│     Finder · 1h                          │
├──────────────────────────────────────────┤
│                            Clear All  🗑  │
└──────────────────────────────────────────┘
```

Each row shows: the ⌘-number badge (first nine visible rows only), a leading
thumbnail for image and file entries, the title, and a footer line with the
source app icon, app name, and relative time. Text entries with more than one
line show a second-line snippet, as `CaptureRow` does today.

Relative time formatting reuses the same scheme as `CaptureRow.relativeTime`
(`<1 min`, `5 min`, `3h`, `2d`, `4mo`, `1y`).

### Keyboard

| Key | Action |
|---|---|
| (on open) | Search field is focused; typing filters immediately |
| `⌘1`–`⌘9` | Select the 1st–9th **visible** row |
| `↑` / `↓` | Move selection |
| `⏎` | Select the highlighted row |
| `esc` | Close the panel |

⌘1–9 map to *visible* rows, so after typing a search query ⌘1 picks the top
result, not the globally-newest entry. Rows past the ninth show no badge.

These are panel-scoped SwiftUI `.keyboardShortcut` bindings, active only while
the panel is key — they do not affect other applications.

### Empty states

- No entries at all: the `κ` glyph and *"No clipboard history yet"*, matching
  `HistoryEmptyState`.
- No search matches: magnifying-glass glyph and *"No matches found"*.
- Clipboard history disabled in settings: a short line explaining it is off, with
  a button that opens the Clipboard settings tab.

---

## 6. Selecting an entry — `PasteService`

### Sequence

1. **Before showing the panel**, capture
   `NSWorkspace.shared.frontmostApplication` as `previousApp`.
2. On selection, write the entry to `NSPasteboard.general`:
   - text → `setString(_:forType: .string)`
   - image → write the full-size PNG as an `NSImage`
   - files → `writeObjects` with the file `URL`s
3. Record the resulting `changeCount` with the monitor so this write is not
   re-ingested.
4. Close the panel.
5. If the behavior setting is **Copy only**, stop here.
6. Otherwise: `previousApp?.activate()`, then after a short settle delay post a
   synthetic ⌘V — a `CGEvent` key-down/key-up pair for keyCode 9 with
   `.maskCommand`, posted to `.cghidEventTap`.

### Accessibility permission

Step 6 requires Accessibility. `TypingService.ensureAccessibilityPermission()`
already implements the check and the System Settings prompt; `PasteService`
reuses it rather than duplicating the alert.

If permission is not granted, the entry is still copied to the clipboard (steps
1–4 always succeed) and the user is told the paste step was skipped. Copy-only is
always the safe fallback — a missing permission never means nothing happens.

### The settings choice

*On selecting an item*:

- **Copy and paste** (default) — the full sequence above.
- **Copy only** — steps 1–4; the user presses ⌘V themselves. Needs no
  Accessibility permission.

---

## 7. Hotkey

Default **⌥C** — `CustomShortcut(keyCode: 8, modifiers: 524288)` (keyCode 8 = `c`,
524288 = `NSEvent.ModifierFlags.option.rawValue`).

Registered through the existing `HotkeyManager` Carbon path as **hotkey id 6**
under the existing `KIMO` signature, alongside capture (1), history (2), escape
(3), type-it (4), and move-mouse (5). A new `onClipboard` callback is added and
wired in `MiniMeApp.setupHotkeys()`.

`HotkeyManager.updateShortcuts` currently takes four positional parameters and is
called from five places in `MiniMeApp`. Rather than growing it to five positional
parameters, it changes to take a single `Shortcuts` struct — one value passed
from `SettingsManager`, one `onChange` handler in `MiniMeApp` instead of four
near-identical ones. This is a contained cleanup of code the feature has to touch
anyway.

**Known trade-off:** ⌥C produces `ç` on a Mac keyboard. Registering it globally
means the user loses that character system-wide while MiniMe runs. This was
raised with the user and accepted; the shortcut is remappable in the Shortcuts
settings tab.

Opening the picker closes any other MiniMe panel first (preview, history,
settings), matching how the existing hotkey handlers behave.

---

## 8. Settings

### New "Clipboard" tab

Placed between **Mouse** and **Shortcuts**, with icon `doc.on.clipboard.fill` and
an indigo-to-teal gradient, following the established `SettingsTabButton` pattern.

| Setting | Type | Default |
|---|---|---|
| Enable clipboard history | Toggle | on |
| On selecting an item | Picker: Copy and paste / Copy only | Copy and paste |
| Capture images and files | Toggle | on |
| Ignore password-manager clipboard | Toggle | on |
| History limit | Picker: 50 / 100 / 200 / 500 | 200 |
| Open clipboard picker | `ShortcutRecorderButton` | ⌥C |
| Clear clipboard history | Destructive button with confirmation | — |

Turning *Enable clipboard history* off stops the poll timer and leaves existing
entries intact. Turning *Capture images and files* off means only text is
captured; existing image and file entries remain.

### Shortcuts tab

A "Clipboard" section is added with the same `ShortcutRecorderButton`, bound to
the same setting, so it can be changed from either place. `resetToDefaults()`
restores ⌥C along with the others.

### Window width

The tab bar goes from 7 to 8 items, so `SettingsView` widens from 600 to 680
points. `SettingsManager.showSettingsWindow` sets the matching content size.

---

## 9. Menu bar

A **Clipboard** item is added to `MenuContentView` between *History* and the
divider, with icon `doc.on.clipboard` and a `DynamicKeyboardShortcut` showing the
configured shortcut, following the pattern of the existing items. The fallback
`NSMenu` in `showPopupMenu()` gets a matching entry, with a corresponding
`AppDelegate.menuClipboard` action.

---

## 10. Component boundaries

| Component | Responsibility | Depends on |
|---|---|---|
| `ClipboardEntry` | Value type, title generation, search matching, codability | Foundation |
| `ClipboardStore` | Load/save, add with dedup, evict, delete, clear, orphan sweep, blob paths | `ClipboardEntry`, FileManager |
| `ClipboardMonitor` | Poll pasteboard, classify content, detect sensitive/self writes, resolve source app | `ClipboardStore`, `ClipboardThumbnailer`, AppKit |
| `ClipboardThumbnailer` | Produce and cache thumbnails for images and files | QuickLookThumbnailing, AppKit |
| `PasteService` | Write to pasteboard, reactivate previous app, synthesize ⌘V | `TypingService` (permission check), CoreGraphics |
| `ClipboardPickerView` | Search, list, keyboard handling, empty states | `ClipboardStore` |
| `ClipboardRow` | Render one entry | `ClipboardEntry` |
| `ActiveScreenResolver` | Resolve the screen the user is on; center and clamp a rect within it | AppKit (pure core takes plain rects) |
| `ClipboardPanelController` | Panel lifecycle, positioning, click-outside, focus capture | AppKit, `ClipboardPickerView`, `ActiveScreenResolver` |
| `ClipboardSettingsView` | Settings UI | `SettingsManager` |

The store never touches AppKit pasteboard APIs and the monitor never touches
disk directly — this keeps the store unit-testable without a real pasteboard.

All manager types are `@MainActor`, consistent with the rest of the codebase.

---

## 11. Files

**New**

```
MiniMe/Models/ClipboardEntry.swift
MiniMe/Clipboard/ClipboardStore.swift
MiniMe/Clipboard/ClipboardMonitor.swift
MiniMe/Clipboard/ClipboardThumbnailer.swift
MiniMe/Clipboard/ClipboardPanelController.swift
MiniMe/Clipboard/ClipboardPickerView.swift
MiniMe/Clipboard/ClipboardRow.swift
MiniMe/Services/PasteService.swift
MiniMe/Settings/ClipboardSettingsView.swift
MiniMe/UI/ActiveScreenResolver.swift
MiniMeTests/ClipboardEntryTests.swift
MiniMeTests/ClipboardStoreTests.swift
MiniMeTests/ActiveScreenResolverTests.swift
MiniMeTests/ClipboardThumbnailerTests.swift
MiniMeTests/ClipboardMonitorTests.swift
```

**Modified**

```
MiniMe/Models/CustomShortcut.swift        defaultClipboard
MiniMe/Managers/HotkeyManager.swift       hotkey id 6, onClipboard, Shortcuts struct
MiniMe/Managers/SettingsManager.swift     clipboard settings, clipboardShortcut
MiniMe/App/MiniMeApp.swift                store/monitor lifecycle, hotkey wiring, menu item
MiniMe/Settings/SettingsView.swift        Clipboard tab, width 680
MiniMe/Settings/ShortcutsSettingsView.swift  Clipboard section
```

**Xcode project:** the project uses `PBXFileSystemSynchronizedRootGroup`
(`objectVersion = 77`), so files created under `MiniMe/` and `MiniMeTests/` are
picked up by their targets automatically. **No `project.pbxproj` edits are
needed.** Swift autolinking resolves `import QuickLookThumbnailing` with no
"Link Binary With Libraries" entry. No external dependencies are added.

The new `ActiveScreenResolver.swift` lives in `MiniMe/UI/` alongside the other
AppKit helpers.

---

## 12. Error handling

| Failure | Behavior |
|---|---|
| `clipboard.json` fails to decode | Start empty, log, do not delete the file |
| Blob write fails | Entry is not added; log |
| Thumbnail generation fails | Entry keeps `thumbnailFileName == nil`; row shows a generic type glyph |
| Referenced file no longer exists | Row renders dimmed with "File no longer available"; selection is a no-op |
| Accessibility not granted | Copy succeeds, paste step skipped, user informed |
| Hotkey registration fails (already taken) | Log the non-zero `OSStatus`, as existing hotkeys do |
| Image over 25 MB | Not captured; no user-visible error |

---

## 13. Testing

### Unit tests (Swift Testing, `@Test`)

`ClipboardEntryTests`

- Codable round-trip for each of the three content kinds
- Title generation: short text, long text truncation at 50 with `...`, blank →
  `"Untitled"`, image dimensions, single file name, multi-file count
- Search matching: title hit, full-text hit for text entries, file-name hit for
  file entries, case insensitivity, image matchable by title only

`ClipboardStoreTests` (against a temporary directory, not the real container)

- Add and retrieve, newest first
- Duplicate text moves the existing entry to the top and refreshes its timestamp
  instead of appending
- Exceeding the limit evicts the oldest and deletes its blob files
- Lowering the configured limit evicts immediately
- Delete by id removes the entry and its blobs
- `clearAll` empties the store and the blob directory
- Orphan sweep deletes unreferenced blob files on load
- Corrupt JSON yields an empty store rather than a crash

`ActiveScreenResolverTests`

- Mouse inside one screen's frame selects that screen
- Mouse exactly on a screen's `maxX`/`maxY` edge still resolves to that screen
  (the `CGRect.contains` exclusion case)
- Mouse in dead space between two offset displays resolves to the nearer one
- Single-screen setup always resolves to index 0
- Empty screen list returns `nil` rather than crashing
- `centeredRect` centers within `visibleFrame`
- `centeredRect` clamps a panel larger than the screen to stay fully on-screen

`ClipboardMonitorTests` (against a private `NSPasteboard(name:)`, not `.general`)

- Text write is captured as a `.text` entry
- Unchanged `changeCount` produces no duplicate entry
- A pasteboard carrying `org.nspasteboard.ConcealedType` is skipped
- `acknowledgeSelfWrite()` suppresses ingestion of MiniMe's own write
- Whitespace-only text is not captured

`ClipboardThumbnailerTests`

- `pngData(from:fitting:)` downsamples a 1000×500 image to fit 240 on the long
  edge while preserving aspect ratio
- An image already smaller than the limit is not upscaled

### Not unit tested

QuickLook file thumbnailing, ⌘V synthesis, and real multi-monitor placement
depend on live system state and are verified manually. Manual checklist:

- Copy text in Safari → appears with Safari icon and name
- Copy an image → thumbnail renders; pasting reproduces the image
- Copy an audio file in Finder → waveform icon; pasting into Finder pastes the file
- Copy a PDF → first-page preview
- Copy from a password manager → not recorded
- ⌥C from a text field → ⌘1 pastes into that field with focus restored
- Search, then ⌘1 → picks the top *result*
- Copy-only mode → clipboard updated, no paste
- Restart the app → file thumbnails still render
- Multi-monitor → panel centers on the screen holding the mouse
- Multi-monitor → move to the second display, press the hotkey again, panel
  follows to that display
- Multi-monitor with mismatched sizes arranged off-centre → panel still lands on
  the screen being used, not the primary one
- Panel opened on a small display → fully on-screen, clear of menu bar and Dock

---

## 14. Decisions and rationale

**Separate store from OCR history.** Different lifecycle, different volume,
different content types. Merging them would complicate both.

**Files over UserDefaults.** Image blobs make UserDefaults unsuitable; it is
loaded wholesale and rewritten on every change.

**200-entry default.** Roughly a week of heavy copying, low tens of megabytes on
disk given the 25 MB per-image cap.

**⌘1–9 scoped to the panel, not global.** Global ⌘1–9 would hijack tab switching
in browsers, channel switching in Slack, navigators in Xcode, and view modes in
Finder. Panel-scoped bindings give the same speed with no conflicts.

**Thumbnails cached eagerly.** Required by the sandbox's read-time-only grant on
pasteboard file URLs, not an optimization.

**QuickLook over plain file icons.** The user asked to preview all files. QuickLook
gives real previews where they exist and falls back to the system type icon
elsewhere, which is already correct for audio and other non-previewable types.

**Files read before images before text.** A Finder file copy also puts text on the
pasteboard; without ordering, file copies would be misclassified.

**`HotkeyManager.updateShortcuts` takes a struct.** A fifth positional parameter
would mean five call sites each passing five arguments. Contained cleanup of code
this feature already has to modify.
