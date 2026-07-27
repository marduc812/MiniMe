//
//  SettingsView.swift
//  MiniMe
//

import SwiftUI

/// One entry in the Settings tab bar.
///
/// Tabs are described as data rather than a hardcoded run of buttons because a
/// tab can now disappear: `requires` names the tool that must be switched on
/// for the tab to show. Selection is tracked by `id` rather than an index,
/// which would shift as tabs come and go.
private struct SettingsTab: Identifiable {
    let id: String
    let title: String
    let icon: String
    let gradient: LinearGradient
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
        SettingsTab(
            id: "general",
            title: "General",
            icon: "gearshape.fill",
            gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        SettingsTab(
            id: "capture",
            title: "Capture",
            icon: "text.viewfinder",
            gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
            requires: .capture
        ),
        SettingsTab(
            id: "typeIt",
            title: "Type It",
            icon: "keyboard.fill",
            gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
            requires: .typeIt
        ),
        SettingsTab(
            id: "scheduler",
            title: "Scheduler",
            icon: "alarm.fill",
            gradient: LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        SettingsTab(
            id: "mouse",
            title: "Mouse",
            icon: "cursorarrow.motionlines",
            gradient: LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            requires: .moveMouse
        ),
        SettingsTab(
            id: "clipboard",
            title: "Clipboard",
            icon: "doc.on.clipboard.fill",
            gradient: LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
            requires: .clipboard
        ),
        SettingsTab(
            id: "shortcuts",
            title: "Shortcuts",
            icon: "command.square.fill",
            gradient: LinearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        SettingsTab(
            id: "about",
            title: "About",
            icon: "info.circle.fill",
            gradient: LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
    ]

    private var visibleTabs: [SettingsTab] {
        Self.allTabs.filter { tab in
            guard let required = tab.requires else { return true }
            return settings.isEnabled(required)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 2) {
                Spacer()

                ForEach(visibleTabs) { tab in
                    SettingsTabButton(
                        title: tab.title,
                        icon: tab.icon,
                        gradient: tab.gradient,
                        isSelected: selectedTab == tab.id,
                        badge: tab.id == "about" && updateManager.updateAvailable
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab.id }
                    }
                }

                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.5)

            // Content
            Group {
                switch selectedTab {
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
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 680, height: 460)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
        .onChange(of: settings.enabledTools) { _, _ in
            // The tab being shown may have just been switched off.
            if !visibleTabs.contains(where: { $0.id == selectedTab }) {
                selectedTab = "general"
            }
        }
    }
}
