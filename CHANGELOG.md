# Changelog

Notable changes to MiniMe, newest first.

## 1.0.12

- Made the clipboard picker smooth to hover with a full history. Moving the
  mouse down the list redrew every visible row, and each row re-ran text
  classification (`NSDataDetector` + a JSON parse, ~0.7 ms), re-decoded its
  thumbnail from disk (~0.9 ms), and re-filtered the whole history to work out
  the highlight. With 200 entries that was 10–15 ms of main-thread work per
  mouse move — more than a frame.
  - Cache text classification per entry (`ClipboardTextKindCache`): a 200-row
    pass went from 146 ms to 0.1 ms.
  - Cache decoded row thumbnails in `ClipboardStore`.
  - Filter the entry list once per redraw instead of once per row.
  - Make `ClipboardRow` `Equatable`, so a hover redraws the two rows that
    changed rather than all of them.
  - Cache source-app icon lookups, which hit LaunchServices on every hover.
