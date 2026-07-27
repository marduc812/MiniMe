# Settings Sidebar Redesign — Design

**Date:** 2026-07-27
**Status:** Approved

## Goal

Modernize the Settings window: replace the custom top tab bar with a
System-Settings-style sidebar layout, flatten the visual noise (per-tab
gradients, ad-hoc row icon colors), and remove per-row boilerplate in the
tab views. No behavior changes.

## Layout

- `SettingsView` becomes a two-pane window, ~760×470.
- Left: fixed, non-collapsible sidebar (~210 pt) rendered as a `.sidebar`
  style `List` with selection, over the existing `VisualEffectView`
  sidebar material.
- Each sidebar row: small rounded-square icon tile (flat tint) + title.
  The red "update available" dot stays on the About row.
- Right: scrollable content pane with a large title header naming the
  selected tab (System Settings style). Tab content below the header.

## Preserved behavior

- Tab visibility via `requires:`; selection falls back to General when
  the visible tab's tool is switched off (`onChange(of: enabledTools)`).
- Accessibility identifiers, notably `tool-toggle-<rawValue>` used by UI
  tests.
- All settings keys, `SettingsManager`, and window plumbing except the
  frame size.

## Visual cleanup

- The eight per-tab `LinearGradient`s become flat tint `Color`s
  (General blue, Capture orange, Type It purple, Scheduler pink,
  Mouse indigo, Clipboard teal, Shortcuts green, About gray).
- Row icons inside each tab use that tab's tint consistently instead of
  the current ad-hoc mix.
- `SettingsTabButton.swift` is deleted.
- `SettingsRowIcon` stays; a new `SettingsRow` wrapper view removes the
  repeated `HStack(spacing: 10) { SettingsRowIcon(...) ... }` pattern in
  every form row.

## Content panes

- All tabs keep their grouped `Form`s; they adopt `SettingsRow` and the
  unified tint.
- About keeps its centered layout inside the detail pane.

## Verification

- Clean release build; existing unit tests pass.
- Launch the app and visually confirm the window in light and dark mode.
