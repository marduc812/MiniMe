#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/minime-freeze.XXXXXX")"
trap 'rm -rf "$probe_dir"' EXIT

cd "$repo_dir"
app_dir="$probe_dir/ClipboardFreezeProbe.app"
bin_dir="$app_dir/Contents/MacOS"
mkdir -p "$bin_dir"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.evaidon.minime.freezeprobe</string>
<key>CFBundleExecutable</key><string>Probe</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST

swiftc -O -parse-as-library \
  -module-cache-path "${TMPDIR:-/tmp}/minime-freeze-module-cache" \
  MiniMe/Models/ClipboardEntry.swift \
  MiniMe/Clipboard/ClipboardStore.swift \
  MiniMe/Clipboard/ClipboardMonitor.swift \
  MiniMe/Clipboard/ClipboardReadWorker.swift \
  MiniMe/Clipboard/ClipboardThumbnailer.swift \
  scripts/clipboard-freeze-probe.swift \
  -o "$bin_dir/Probe"

swiftc -O -parse-as-library \
  -module-cache-path "${TMPDIR:-/tmp}/minime-freeze-module-cache" \
  MiniMe/Models/ClipboardEntry.swift \
  MiniMe/Clipboard/ClipboardReadWorker.swift \
  MiniMe/Clipboard/ClipboardThumbnailer.swift \
  MiniMeClipboardWorker/WorkerEntry.swift \
  -o "$bin_dir/MiniMeClipboardWorker"

# The synthetic provider runs in a child process too. Give both children only
# sandbox inheritance; the parent gets the same sandbox as the shipping app.
cp "$bin_dir/Probe" "$bin_dir/ProbeProvider"
codesign --force --sign - --entitlements MiniMeClipboardWorker/Worker.entitlements "$bin_dir/ProbeProvider"
codesign --force --sign - --entitlements MiniMeClipboardWorker/Worker.entitlements "$bin_dir/MiniMeClipboardWorker"
codesign --force --sign - --entitlements MiniMe/MiniMe.entitlements "$app_dir"
if [ "${1:-}" = "--all" ]; then
  "$bin_dir/Probe"
  "$bin_dir/Probe" --timeout
  "$bin_dir/Probe" --image
  "$bin_dir/Probe" --file
else
  "$bin_dir/Probe" "$@"
fi
