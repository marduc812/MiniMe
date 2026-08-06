//
//  Tool.swift
//  MiniMe
//

import Foundation

/// A user-facing tool that can be switched on or off in Settings.
///
/// Turning a tool off hides its menu bar item, unregisters its global hotkey,
/// and hides its Settings tab. This enum is the single source of truth for
/// which tools exist — the Tools section, the menu, the tab bar, the Shortcuts
/// tab and hotkey registration all derive from it.
///
/// The Scheduler is deliberately absent: it has no menu bar presence and stays
/// inert until explicitly armed, so a switch would add UI without removing
/// anything.
enum Tool: String, CaseIterable, Identifiable, Sendable {
    case capture
    case typeIt
    case clipboard
    case moveMouse
    case preventSleep
    case paper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capture:      return "Capture"
        case .typeIt:       return "Type It"
        case .clipboard:    return "Clipboard"
        case .moveMouse:    return "Move Mouse"
        case .preventSleep: return "Prevent Sleep"
        case .paper:        return "Paper"
        }
    }

    var icon: String {
        switch self {
        case .capture:      return "text.viewfinder"
        case .typeIt:       return "keyboard"
        case .clipboard:    return "doc.on.clipboard"
        case .moveMouse:    return "cursorarrow.motionlines"
        case .preventSleep: return "moon.zzz"
        case .paper:        return "camera.filters"
        }
    }

    var defaultsKey: String { "tool.\(rawValue).enabled" }

    // MARK: - Persistence

    /// Reads which tools are enabled. An absent key means enabled, so existing
    /// installs and fresh installs both start with every tool on.
    static func enabledSet(from defaults: UserDefaults) -> Set<Tool> {
        Set(allCases.filter { defaults.object(forKey: $0.defaultsKey) as? Bool ?? true })
    }

    static func setEnabled(_ enabled: Bool, for tool: Tool, in defaults: UserDefaults) {
        defaults.set(enabled, forKey: tool.defaultsKey)
    }

    /// The clipboard manager shipped with its own `clipboardHistoryEnabled`
    /// setting, now replaced by `Tool.clipboard`. Carry a user's existing choice
    /// across so nobody gets the monitor silently switched back on.
    static func migrateLegacyKeys(in defaults: UserDefaults) {
        let legacyKey = "clipboardHistoryEnabled"
        guard let legacyValue = defaults.object(forKey: legacyKey) as? Bool else { return }

        // Only adopt the legacy value if the user hasn't already expressed a
        // preference under the new key.
        if defaults.object(forKey: Tool.clipboard.defaultsKey) == nil {
            setEnabled(legacyValue, for: .clipboard, in: defaults)
        }
        defaults.removeObject(forKey: legacyKey)
    }
}
