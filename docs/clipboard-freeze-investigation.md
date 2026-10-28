MiniMe freeze investigation, 28 October 2026

The clipboard capture path can block MiniMe's main thread for seconds. This
prevents menu clicks and global shortcut callbacks from being handled. Two
reproductions below use the actual application classes with a private pasteboard,
temporary storage, and synthetic content. They do not use the general clipboard
or the user's saved history. No memory-monitor agent runs during these tests.

The tested checkout is based on cbe68f7. ClipboardMonitor and ClipboardThumbnailer
are unchanged from the installed 1.1.0 release at d8beb15. The store has gained
moveToTop since that release, which neither reproduction calls.

Confirmed failure paths

- Slow clipboard providers block the UI. ClipboardMonitor is main-actor isolated.
  Its timer calls poll every 0.5 seconds, and poll synchronously calls
  readContent. Reading a string or image may require another process to supply
  its promised clipboard data. The private provider in the reproduction waits
  four seconds before supplying text. In an optimized build, poll took 4.027
  seconds. A main-queue callback scheduled for 0.1 seconds could only run at
  4.027 seconds. This directly demonstrates the UI stall, although the test
  deliberately chooses the provider's delay. See
  MiniMe/Clipboard/ClipboardMonitor.swift, lines 45, 63, and 109.
- Image capture blocks the UI even when the image is rejected. The monitor asks
  for an NSImage, obtains its full TIFF representation, decodes that into a
  bitmap, and encodes a PNG. Only then does it enforce maxImageBytes. A synthetic
  6000 by 4000 image containing random pixels took 3.996 seconds in one run and
  6.427 seconds in another, and produced no history entry because it exceeded
  the limit. The latter run reported a 653,611,008-byte peak physical footprint,
  about 623 MiB, and a 998,367,232-byte maximum resident set. Those are whole-probe
  peaks, including creation and publication of the synthetic image. They are
  not measurements of ordinary screenshots or MiniMe's idle footprint. See
  MiniMe/Clipboard/ClipboardMonitor.swift, lines 101 and 114, and
  MiniMe/Clipboard/ClipboardThumbnailer.swift, line 60.

Additional blocking operations found in the source

- ClipboardStore synchronously encodes and atomically writes the entire history
  on the main actor after mutations. Blob writes, eviction, startup loading,
  and orphan cleanup also perform filesystem work there. There is no total text
  byte limit, so a history limited to 200 entries can still be large. This is a
  confirmed placement of blocking work, but its contribution to reported freezes
  has not been measured.
- Image thumbnail generation is wrapped in Task with MainActor isolation.
  Reading the blob, decoding it, drawing it, and writing the thumbnail still run
  on the UI thread. Scheduling a task does not move that work off the actor.
- ClipboardRow calls hasMissingFiles during rendering. ClipboardDetailView also
  calls fileExists and icon(forFile:) while building file previews. These touch
  paths copied earlier, which can point to slow or disconnected volumes. This
  is a plausible cause when opening history containing files, not a reproduced
  network-volume stall.

Relationship to the earlier incident

The unresponsive installed process was restarted successfully and both the menu
and Option+C then worked. A vmmap inspection had been stuck near the time of
that incident, but the saved sample showed an idle main run loop rather than a
stack inside clipboard capture. It does not prove the monitor caused the hang,
nor does it prove which clipboard operation caused that particular incident.
The reproductions establish independent defects in the application. Disabling
the local memory monitor is not a general fix for customers.

Reproduction

Run these commands from the repository root on macOS with Xcode installed:

```sh
bash scripts/diagnose-clipboard-freeze.sh
bash scripts/diagnose-clipboard-freeze.sh --image
```

The first command launches a separate provider process for a uniquely named
pasteboard. The second uses synthetic image data. Both print poll's elapsed
time and the delayed main-queue callback time. The provider, pasteboard, and
temporary history are cleaned up on normal completion. Image timings vary with
the machine and load. The repaired probe asserts responsiveness and worker recovery. The timing
measurements above describe the original implementation.

Implemented repair

ClipboardReadService now owns an embedded command-line helper. All synchronous
clipboard content reads, image checks, conversion, and capture-time thumbnails
run in that helper. Pipe I/O and JSON decoding run on a private utility queue.
The app awaits the result and keeps the main actor available for menu clicks and
shortcuts. A five-second deadline kills a stalled helper. The next clipboard
change starts another helper, and the same stalled copy is not retried forever.
Only one read runs at a time. Clipboard-generation and configuration checks
reject stale results, including results that finish after capture is disabled or
a self-write is acknowledged. Concealed-content filtering remains in place.

ImageIO checks image dimensions before decoding, rejects images above 40 million
pixels, and retains suitable PNG data without a TIFF conversion. The 25 MiB
encoded limit remains. Text copies above 4 MiB are skipped. Image previews are
downsampled off the main actor instead of decoding a full-resolution image in the
picker.

ClipboardStore now loads history, sweeps orphans, serializes snapshots, and writes
or deletes blobs on one ordered utility queue. Mutations made during initial
loading are replayed against the saved history. Shutdown asynchronously waits for
queued saves. File existence checks and file icons in the picker, as well as
file validation and image reads for paste operations, no longer run on the UI
thread.

The release helper uses Apple's required sandbox and inheritance entitlements.
It is a separate build target embedded in Contents/MacOS. Debug helpers omit
explicit sandbox entitlements because Xcode's test preparation adds incompatible
sandbox exceptions to inherited-sandbox executables. A child still inherits the
parent's sandbox at runtime. The signed probe separately exercises the release
entitlements with a sandboxed parent, so testing does not depend solely on this
Debug accommodation. See [Apple's helper-tool documentation](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app).

Verification

The signed sandboxed reproduction now asserts a main-queue callback runs within
0.5 seconds. Run all scenarios with:

```sh
bash scripts/diagnose-clipboard-freeze.sh --all
```

On this machine the callback ran at 0.101 seconds during a four-second provider
read. It ran at 0.101 seconds during a stalled-provider timeout, after which the
worker restarted and captured a new copy. During the oversized-image test it ran
at 0.102 seconds, while rejection completed after 0.323 seconds. These are
measurements of the repaired pipeline, not guarantees about every machine.

Unit tests also cover persistence order, mutations and clearing during initial
loading, rejection of stale results, suppression of overlapping reads, and
invalidating reads when capture stops or a self-write is acknowledged. Existing
clipboard capture, concealed-content, blob lifecycle, and thumbnail tests are
included in validation. The final clipboard regression run passed all 45 tests.
A full unit run passed 356 tests. Two unrelated OCR fixture tests failed because
the ignored local ocr-fixtures.json manifest is absent from this checkout.

The signed probe also passed file capture, thumbnail generation, and transfer of
temporary file access from the helper back to the app. That transfer uses
[URL bookmarks with implicit security scope](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox),
so the parent does not lose the file access previously granted directly by the
pasteboard. These temporary grants are released when entries leave the store.

The repair addresses the demonstrated failure paths. The original incident's
sample remains inconclusive about the precise operation that stalled that
process. No repaired release has been published or installed automatically.

A local ad-hoc signed test build is available at build/freeze-fix/MiniMe.app.
Its embedded helper and app signatures passed strict verification. The installed
copy in /Applications has not been replaced. Quit that copy before launching
the test build, because the single-instance guard otherwise activates it.
