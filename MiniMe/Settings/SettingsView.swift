//
//  SettingsView.swift
//  MiniMe
//

import SwiftUI

/// One entry in the Settings sidebar.
///
/// Tabs are described as data rather than a hardcoded run of rows because a
/// tab can be switched off: `requires` names the tool that must be enabled
/// for the tab to be selectable. Disabled tabs stay visible but grayed out,
/// so the user can see the tool exists. Selection is tracked by `id` rather
/// than an index, which would shift if tabs were ever reordered.
private struct SettingsTab: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    /// `nil` means the tab is always available.
    var requires: Tool? = nil
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var clipboardStore: ClipboardStore
    @State private var selectedTab = "general"

    private static let allTabs: [SettingsTab] = [
        SettingsTab(id: "general", title: "General", icon: "gearshape.fill", tint: .blue),
        SettingsTab(id: "capture", title: "Capture", icon: "text.viewfinder", tint: .orange, requires: .capture),
        SettingsTab(id: "typeIt", title: "Type It", icon: "keyboard.fill", tint: .purple, requires: .typeIt),
        SettingsTab(id: "scheduler", title: "Scheduler", icon: "alarm.fill", tint: .pink),
        SettingsTab(id: "mouse", title: "Mouse", icon: "cursorarrow.motionlines", tint: .indigo, requires: .moveMouse),
        SettingsTab(id: "clipboard", title: "Clipboard", icon: "doc.on.clipboard.fill", tint: .teal, requires: .clipboard),
        SettingsTab(id: "shortcuts", title: "Shortcuts", icon: "command.square.fill", tint: .green),
        SettingsTab(id: "about", title: "About", icon: "info.circle.fill", tint: .gray),
    ]

    private func isEnabled(_ tab: SettingsTab) -> Bool {
        guard let required = tab.requires else { return true }
        return settings.isEnabled(required)
    }

    private var currentTab: SettingsTab {
        Self.allTabs.first { $0.id == selectedTab } ?? Self.allTabs[0]
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 760, height: 470)
        .onChange(of: settings.enabledTools) { _, _ in
            // The tab being shown may have just been switched off.
            if !isEnabled(currentTab) {
                selectedTab = "general"
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Self.allTabs) { tab in
                sidebarRow(tab)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        }
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        let enabled = isEnabled(tab)
        let isSelected = tab.id == selectedTab

        return Button {
            selectedTab = tab.id
        } label: {
            HStack(spacing: 8) {
                SettingsRowIcon(systemName: tab.icon, color: tab.tint, size: 22)
                Text(tab.title)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
                if tab.id == "about" && updateManager.updateAvailable {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                        .accessibilityLabel("Update available")
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(enabled ? tab.title : "\(tab.title), disabled")
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(currentTab.title)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.top, 14)

            Group {
                switch currentTab.id {
                case "capture":
                    ImageToTextSettingsView(settings: settings)
                case "typeIt":
                    TypeItSettingsView(settings: settings)
                case "scheduler":
                    SchedulerSettingsView(settings: settings)
                case "mouse":
                    MouseMoverSettingsView(settings: settings)
                case "clipboard":
                    ClipboardSettingsView(settings: settings, store: clipboardStore)
                case "shortcuts":
                    ShortcutsSettingsView(settings: settings)
                case "about":
                    AboutSettingsView(updateManager: updateManager)
                default:
                    GeneralSettingsView(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
