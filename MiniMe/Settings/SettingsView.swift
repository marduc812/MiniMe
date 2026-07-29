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

/// Tabs are shown under a heading rather than as one long run, so the tool tabs
/// — the ones that come and go as tools are switched on and off — are visibly a
/// set, separate from the tabs that are always there.
private struct SettingsTabGroup: Identifiable {
    var id: String { heading }
    let heading: String
    let tabs: [SettingsTab]
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var clipboardStore: ClipboardStore
    @State private var selectedTab = "general"

    private static let tabGroups: [SettingsTabGroup] = [
        SettingsTabGroup(heading: "General", tabs: [
            SettingsTab(id: "general", title: "General", icon: "gearshape.fill", tint: .blue),
        ]),
        SettingsTabGroup(heading: "Tools", tabs: [
            SettingsTab(id: "capture", title: "Capture", icon: "text.viewfinder", tint: .orange, requires: .capture),
            SettingsTab(id: "typeIt", title: "Type It", icon: "keyboard.fill", tint: .purple, requires: .typeIt),
            SettingsTab(id: "scheduler", title: "Scheduler", icon: "alarm.fill", tint: .pink),
            SettingsTab(id: "mouse", title: "Mouse", icon: "cursorarrow.motionlines", tint: .indigo, requires: .moveMouse),
            SettingsTab(id: "clipboard", title: "Clipboard", icon: "doc.on.clipboard.fill", tint: .teal, requires: .clipboard),
        ]),
        SettingsTabGroup(heading: "App", tabs: [
            SettingsTab(id: "shortcuts", title: "Shortcuts", icon: "command.square.fill", tint: .green),
            SettingsTab(id: "about", title: "About", icon: "info.circle.fill", tint: .gray),
        ]),
    ]

    private static let allTabs: [SettingsTab] = tabGroups.flatMap(\.tabs)

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
            ForEach(Array(Self.tabGroups.enumerated()), id: \.element.id) { index, group in
                Text(group.heading.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.top, index == 0 ? 2 : 14)
                    .padding(.bottom, 3)
                    .accessibilityAddTraits(.isHeader)

                ForEach(group.tabs) { tab in
                    sidebarRow(tab)
                }
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
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // A tinted capsule rather than a solid accent bar: the icon tiles are
        // already saturated, and a solid fill behind them fought with them.
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .background {
            if isSelected {
                Capsule().fill(Color.accentColor.opacity(0.18))
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
            // Grouped forms paint their own scroll background, which is a
            // different shade than the pane behind the title — the seam read as
            // a rendering glitch. Hiding it lets one background run the full
            // height of the detail pane, with only the section boxes on top.
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
