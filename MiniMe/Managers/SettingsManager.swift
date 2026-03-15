//
//  SettingsManager.swift
//  MiniMe
//

import SwiftUI
import ServiceManagement

@MainActor
class SettingsManager: ObservableObject {
    @AppStorage("autoCopyToClipboard") var autoCopyToClipboard = true
    @AppStorage("playSound") var playSound = true
    @AppStorage("recognitionLanguage") var recognitionLanguage = "en-US"
    @AppStorage("lineAwareOCR") var lineAwareOCR = true
    @AppStorage("ocrAccuracy") var ocrAccuracy = "accurate"
    @AppStorage("typeItCountdownDuration") var typeItCountdownDuration = 5

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    @Published var captureShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var historyShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }
    @Published var typeItShortcut: CustomShortcut {
        didSet { saveShortcuts() }
    }

    private var settingsWindow: NSWindow?

    init() {
        if let data = UserDefaults.standard.data(forKey: "captureShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            captureShortcut = shortcut
        } else {
            captureShortcut = .defaultCapture
        }

        if let data = UserDefaults.standard.data(forKey: "historyShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            historyShortcut = shortcut
        } else {
            historyShortcut = .defaultHistory
        }

        if let data = UserDefaults.standard.data(forKey: "typeItShortcut"),
           let shortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            typeItShortcut = shortcut
        } else {
            typeItShortcut = .defaultTypeIt
        }
    }

    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(captureShortcut) {
            UserDefaults.standard.set(data, forKey: "captureShortcut")
        }
        if let data = try? JSONEncoder().encode(historyShortcut) {
            UserDefaults.standard.set(data, forKey: "historyShortcut")
        }
        if let data = try? JSONEncoder().encode(typeItShortcut) {
            UserDefaults.standard.set(data, forKey: "typeItShortcut")
        }
    }

    func resetToDefaults() {
        captureShortcut = .defaultCapture
        historyShortcut = .defaultHistory
        typeItShortcut = .defaultTypeIt
    }

    func showSettingsWindow(hotkeyManager: HotkeyManager) {
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: self, hotkeyManager: hotkeyManager)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 460))
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}
