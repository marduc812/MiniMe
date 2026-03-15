//
//  SettingsView.swift
//  MiniMe
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var updateManager: UpdateManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 2) {
                Spacer()

                SettingsTabButton(
                    title: "General",
                    icon: "gearshape.fill",
                    color: .blue,
                    isSelected: selectedTab == 0
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 0 }
                }

                SettingsTabButton(
                    title: "Capture",
                    icon: "text.viewfinder",
                    color: .orange,
                    isSelected: selectedTab == 1
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 1 }
                }

                SettingsTabButton(
                    title: "Type It",
                    icon: "keyboard.fill",
                    color: .purple,
                    isSelected: selectedTab == 2
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 2 }
                }

                SettingsTabButton(
                    title: "Shortcuts",
                    icon: "command.square.fill",
                    color: .teal,
                    isSelected: selectedTab == 3
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 3 }
                }

                SettingsTabButton(
                    title: "About",
                    icon: "info.circle.fill",
                    color: Color(.systemGray),
                    isSelected: selectedTab == 4,
                    badge: updateManager.updateAvailable
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 4 }
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
                case 0:
                    GeneralSettingsView(settings: settings)
                case 1:
                    ImageToTextSettingsView(settings: settings)
                case 2:
                    TypeItSettingsView(settings: settings)
                case 3:
                    ShortcutsSettingsView(settings: settings)
                default:
                    AboutSettingsView(updateManager: updateManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 520, height: 460)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                Color.primary.opacity(0.02)
            }
        }
    }
}
