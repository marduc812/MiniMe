//
//  MiniMeApp.swift
//  MiniMe
//
//  Created by marduc812 on 02.02.2026.
//

import SwiftUI
import UserNotifications

extension Notification.Name {
    static let appShouldShowMenu = Notification.Name("appShouldShowMenu")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var onCapture: (() -> Void)?
    var onSettings: (() -> Void)?
    var onClipboard: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .appShouldShowMenu, object: nil)
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    @objc func menuCapture() { onCapture?() }
    @objc func menuSettings() { onSettings?() }
    @objc func menuClipboard() { onClipboard?() }

}

@main
struct MiniMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var screenCapture = ScreenCaptureManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var hotkeyManager = HotkeyManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var updateManager = UpdateManager()
    @StateObject private var clipboardStore = ClipboardStore()
    @StateObject private var clipboardPanel = ClipboardPanelController()
    @State private var clipboardMonitor: ClipboardMonitor?
    @ObservedObject private var typingService = TypingService.shared
    @ObservedObject private var mouseMover = MouseMoverManager.shared
    @ObservedObject private var scheduler = ScheduledActionManager.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @State private var hasSetupHotkeys = false

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuContentView(
                screenCapture: screenCapture,
                settingsManager: settingsManager,
                hotkeyManager: hotkeyManager,
                updateManager: updateManager,
                clipboardStore: clipboardStore,
                showClipboard: { showClipboardPicker() }
            )
        } label: {
            if let count = typingService.countdown {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
            } else if scheduler.isArmed {
                // Show an hourglass while a scheduled action is pending, so the
                // user knows an automated action is about to fire and to wait.
                Image(systemName: "hourglass")
            } else if mouseMover.isArmed {
                // Show a moving-cursor glyph while the mouse mover is active.
                Image(systemName: "cursorarrow.motionlines")
            } else {
                Image(nsImage: {
                    let img = NSImage(named: "MenuBarIcon") ?? NSImage()
                    img.isTemplate = true
                    img.size = NSSize(width: 16, height: 16)
                    return img
                }())
            }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: settingsManager.shortcutSet) { _, newValue in
            hotkeyManager.updateShortcuts(newValue)
        }
        .onChange(of: settingsManager.clipboardHistoryEnabled) { _, enabled in
            enabled ? clipboardMonitor?.start() : clipboardMonitor?.stop()
        }
        .onChange(of: settingsManager.clipboardCaptureImagesAndFiles) { _, newValue in
            clipboardMonitor?.captureImagesAndFiles = newValue
        }
        .onChange(of: settingsManager.clipboardIgnoreConcealed) { _, newValue in
            clipboardMonitor?.ignoreConcealed = newValue
        }
        .onChange(of: settingsManager.clipboardMaxEntries) { _, newValue in
            clipboardStore.maxEntries = newValue
        }
        .onChange(of: hasSetupHotkeys, initial: true) { _, _ in
            if !hasSetupHotkeys {
                hasSetupHotkeys = true
                setupHotkeys()
                setupAppDelegate()
                startClipboardMonitor()
                Task { await updateManager.checkForUpdatesIfNeeded() }
                NotificationCenter.default.addObserver(
                    forName: .appShouldShowMenu,
                    object: nil,
                    queue: .main
                ) { _ in
                    showPopupMenu()
                }
                // Show onboarding if needed
                if onboardingManager.showOnboarding {
                    showOnboardingWindow()
                }
            }
        }
        .onChange(of: onboardingManager.showOnboarding) { _, showOnboarding in
            if !showOnboarding {
                closeOnboardingWindow()
                // Restart hotkey monitoring after permissions are granted
                hotkeyManager.checkAccessibilityPermission()
                hotkeyManager.startMonitoring()
            }
        }
        .onChange(of: screenCapture.needsPermission) { _, needsPermission in
            if needsPermission {
                // Reset the flag and show onboarding
                screenCapture.needsPermission = false
                onboardingManager.resetOnboarding()
                showOnboardingWindow()
            }
        }
    }

    @State private var onboardingWindow: NSWindow?

    private func showOnboardingWindow() {
        if onboardingWindow != nil { return }

        let onboardingView = OnboardingView(onboardingManager: onboardingManager)
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to MiniMe"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 500))
        window.center()
        window.isReleasedWhenClosed = false

        self.onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func setupAppDelegate() {
        appDelegate.onCapture = {
            self.clipboardPanel.close()
            self.settingsManager.closeSettingsWindow()
            self.screenCapture.startAreaSelection()
        }
        appDelegate.onSettings = {
            self.clipboardPanel.close()
            NSApp.activate(ignoringOtherApps: true)
            self.settingsManager.showSettingsWindow(
                hotkeyManager: self.hotkeyManager,
                updateManager: self.updateManager,
                clipboardStore: self.clipboardStore
            )
        }
        appDelegate.onClipboard = {
            self.showClipboardPicker()
        }
    }

    private func startClipboardMonitor() {
        clipboardStore.maxEntries = settingsManager.clipboardMaxEntries

        let monitor = ClipboardMonitor(store: clipboardStore)
        monitor.captureImagesAndFiles = settingsManager.clipboardCaptureImagesAndFiles
        monitor.ignoreConcealed = settingsManager.clipboardIgnoreConcealed
        clipboardMonitor = monitor

        if settingsManager.clipboardHistoryEnabled {
            monitor.start()
        }
    }

    private func showClipboardPicker() {
        guard let clipboardMonitor else { return }
        settingsManager.closeSettingsWindow()

        clipboardPanel.toggle(
            store: clipboardStore,
            settings: settingsManager,
            monitor: clipboardMonitor
        ) {
            NSApp.activate(ignoringOtherApps: true)
            settingsManager.showSettingsWindow(
                hotkeyManager: hotkeyManager,
                updateManager: updateManager,
                clipboardStore: clipboardStore
            )
        }
    }

    private func showPopupMenu() {
        // Try to click the menu bar button first (when icon is visible)
        for window in NSApp.windows {
            guard let contentView = window.contentView else { continue }
            for subview in contentView.subviews {
                if let button = subview as? NSStatusBarButton {
                    button.performClick(nil)
                    return
                }
            }
        }

        // Fallback: show a native popup menu at the mouse location
        NSApp.activate(ignoringOtherApps: true)

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture", action: #selector(AppDelegate.menuCapture), keyEquivalent: "")
        captureItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        captureItem.target = appDelegate
        menu.addItem(captureItem)

        let clipboardItem = NSMenuItem(title: "Clipboard", action: #selector(AppDelegate.menuClipboard), keyEquivalent: "")
        clipboardItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        clipboardItem.target = appDelegate
        menu.addItem(clipboardItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.menuSettings), keyEquivalent: "")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = appDelegate
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        // Show at mouse location in screen coordinates
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    private func setupHotkeys() {
        // Connect screenCapture to hotkeyManager for escape key handling
        screenCapture.setHotkeyManager(hotkeyManager)

        hotkeyManager.updateShortcuts(settingsManager.shortcutSet)
        hotkeyManager.onCapture = {
            self.clipboardPanel.close()
            self.settingsManager.closeSettingsWindow()
            self.screenCapture.startAreaSelection()
        }
        hotkeyManager.onTypeIt = {
            TypingService.shared.typeFromSelection()
        }
        hotkeyManager.onToggleMouseMove = {
            MouseMoverManager.shared.toggle()
        }
        hotkeyManager.onClipboard = {
            self.showClipboardPicker()
        }
        hotkeyManager.startMonitoring()
    }

}

struct MenuContentView: View {
    @ObservedObject var screenCapture: ScreenCaptureManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var clipboardStore: ClipboardStore
    let showClipboard: () -> Void
    @ObservedObject var mouseMover = MouseMoverManager.shared

    var body: some View {
        Group {
            Button {
                DispatchQueue.main.async {
                    settingsManager.closeSettingsWindow()
                    screenCapture.startAreaSelection()
                }
            } label: {
                Label("Capture", systemImage: "text.viewfinder")
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.captureShortcut))

            Button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    TypingService.shared.typeFromSelection()
                }
            } label: {
                Label("Type It", systemImage: "keyboard")
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.typeItShortcut))

            Button {
                DispatchQueue.main.async { showClipboard() }
            } label: {
                Label("Clipboard", systemImage: "doc.on.clipboard")
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.clipboardShortcut))

            Divider()

            Button {
                MouseMoverManager.shared.toggle()
            } label: {
                if mouseMover.isArmed {
                    Label("Stop Moving Mouse", systemImage: "cursorarrow.motionlines")
                } else {
                    Label("Move Mouse", systemImage: "cursorarrow.motionlines")
                }
            }
            .modifier(DynamicKeyboardShortcut(shortcut: settingsManager.moveMouseShortcut))

            Menu {
                ForEach(SleepDuration.allCases) { duration in
                    Button {
                        settingsManager.enablePreventSleep(duration)
                    } label: {
                        if settingsManager.activeSleepDuration == duration {
                            Label(duration.rawValue, systemImage: "checkmark")
                        } else {
                            Text(duration.rawValue)
                        }
                    }
                }
            } label: {
                if let active = settingsManager.activeSleepDuration {
                    Label("Prevent Sleep (\(active.rawValue))", systemImage: "moon.zzz.fill")
                } else {
                    Label("Prevent Sleep", systemImage: "moon.zzz")
                }
            }

            if settingsManager.activeSleepDuration != nil {
                Button {
                    settingsManager.disablePreventSleep()
                } label: {
                    Label("Turn Off Prevent Sleep", systemImage: "moon.fill")
                }
            }

            Divider()

            Button {
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    settingsManager.showSettingsWindow(
                        hotkeyManager: hotkeyManager,
                        updateManager: updateManager,
                        clipboardStore: clipboardStore
                    )
                }
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
