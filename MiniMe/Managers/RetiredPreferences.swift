//
//  RetiredPreferences.swift
//  MiniMe
//

import Foundation

/// Preferences left behind by tools that no longer exist.
///
/// Deleting a tool takes its code but not its keys: those sit in the plist of
/// every install that ever ran the old version, read by nothing and cleared by
/// nothing. This sweeps them at launch so an upgrade leaves the same
/// preferences a fresh install would have.
///
/// New entries go here when a tool is removed, not when one is renamed — a
/// rename needs its value carried across, which is a migration, not a sweep.
/// See `Tool.migrateLegacyKeys(in:)` for that case.
enum RetiredPreferences {

    /// Written by Type It and the Scheduler, both removed in 1.0.14.
    ///
    /// Verified against the 1.0.13 sources rather than recalled: `typeItShortcut`
    /// and `scheduledCombo` were written by `SettingsManager.saveShortcuts()` and
    /// `saveScheduledCombo()`, the rest by `@AppStorage`.
    static let keys: [String] = [
        "typeItShortcut",
        "typeItCountdownDuration",
        "typeItCountdownSound",
        "scheduledCombo",
        "scheduledText",
        "scheduledComboEnabled",
        "scheduledIntervalValue",
        "scheduledIntervalUnit",
        "scheduledRepeat",
    ]

    /// Deletes every retired key. Safe to call on a domain that has none — a
    /// fresh install, or the second launch after an upgrade.
    static func removeAll(from defaults: UserDefaults) {
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}
