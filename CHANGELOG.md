# Changelog

Notable changes to MiniMe, newest first.

## Unreleased

- Stop the clipboard picker from freezing on a large clipping: the preview shows the first 4,000 characters and says how many more there are, and Copy still takes the whole thing.
- Show the clipboard list the moment the picker opens, and fill the preview in behind it.
- Always show first-run setup on a new install: dismissing a single permission slide no longer counts as having been through setup, which is why setup could vanish on a fresh Mac before it had ever appeared.

## 1.0.14

- Add Paper: a translucent paper matte over your displays, so highlights diffuse and contrast softens.
- Pick between six textures—Onionskin, Vellum, Matte, Linen, Parchment and Newsprint—from a grid that previews each one.
- Choose which displays the matte covers; the choice sticks across the hotkey, the menu and a relaunch.
- Set the strength anywhere from 0% to 30%, with the slider showing the opacity it actually renders rather than its own position.
- Switch the matte with its hotkey or its menu bar item; Settings no longer carries a second on/off switch of its own.
- Keep the matte out of screenshots, screen recordings and MiniMe's own captures.
- Remove Type It and the Scheduler, along with their settings panes, shortcuts and menu bar entries.
- Clear the preferences those two left behind, so an upgrade ends up with the same settings a fresh install would have.

## 1.0.13

- Remember Prevent Sleep across restarts—a timed session resumes with only the time it had left, and one that ran out while MiniMe was closed stays off.
- Quit at launch if MiniMe is already running—two copies fought over the same hotkeys, and the one without the Accessibility grant answered them.
- Name the tool that needs Accessibility in the permission alert instead of always saying "simulate typing".

## 1.0.12

- Add a first-run setup deck: a slide per tool with an animation of it in action and a switch.
- Ask for each permission on the slide of the tool that needs it, not all up front.
- Stop prompting for Accessibility on every clipboard paste—the clipboard works fine without it.
- Stop re-deriving clipboard rows on hover—cache classifications, thumbnails, and app icons.
- Give the About icon eyes that follow the cursor.
- Fill the selected Settings tab and drop sidebar icon tiles.
- Make the clipboard preview follow the row you point at.
- Restyle the Settings sidebar and unify the detail pane background.
- Make the Scheduler text box multiline and the interval typeable.
- Icon clipboard text by what it is, and linkify previews.
- Move Prevent Sleep off switch into its submenu.
- Redesign Settings sidebar with clipboard detail view.
- Add per-tool on/off switches in Settings.
- Collapse capture history into the clipboard manager.
- Measure clipboard image previews in pixels, not points.
- Wire the clipboard manager into hotkeys, settings and the menu bar.
- Add option-C clipboard shortcut default.
- Add PasteService for pasteboard writes and synthesized paste.
- Fix PasteService activation before synthesizing paste.
- Add ClipboardMonitor with content classification and sensitive-type filtering.
- Check for updates once a day while running and post notifications.
- Add "Check for updates automatically" to General settings, on by default.

## 1.0.7

- Fix line-grouping order and mixed-height bugs, add column detection.
- Skip redundant second OCR pass to improve performance.
- Improve OCR text parsing with adaptive upscaling and language honoring.

## 1.0.6

- Show an hourglass menu bar icon while a scheduled action is pending.
- Show a moving-cursor menu bar icon while the mouse mover is armed.
- Improve OCR accuracy and add testable engine with regression corpus.
- Add mouse mover, toggle shortcut, and clean up scheduler UI.
- Add scheduled action feature with delayed and repeating type support.

## 1.0.3

- Fixed bug with sleep prevention and Citrix compatibility.

## 1.0.2

- Updated settings colors.
- Add option to check for updates automatically.
- Add option to type selected text.

## 1.0.1

- Change cursor during screenshot to provide visual feedback.
- Show where each screenshot came from in the history.
- Preview the selected history item.
- Add option to hide the icon from the menu bar.
- Show error message when screen recording permission is missing.
- Shorter retention time for history display.
- Fix bug with shortcut key registration.

## Beta

- Initial release with capture history and search functionality.
