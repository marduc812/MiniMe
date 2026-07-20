//
//  ScreenCaptureManager.swift
//  MiniMe
//

import SwiftUI
import ScreenCaptureKit
import UserNotifications

@MainActor
class ScreenCaptureManager: ObservableObject {
    @Published var lastExtractedText: String?
    @Published var lastSourceApp: String?
    @Published var needsPermission: Bool = false

    private var selectionWindows: [SelectionWindow] = []
    private var selectionCoordinator: SelectionCoordinator?
    private var localEventMonitor: Any?
    private weak var hotkeyManager: HotkeyManager?

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func setHotkeyManager(_ manager: HotkeyManager) {
        self.hotkeyManager = manager
    }

    func checkScreenRecordingPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }

    func startAreaSelection() {
        closeAllWindows()

        // Capture the frontmost app before showing overlay (overlay makes MiniMe frontmost)
        lastSourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

        // Check permission first
        Task {
            let hasPermission = await checkScreenRecordingPermission()
            if !hasPermission {
                self.needsPermission = true
                return
            }
            self.continueAreaSelection()
        }
    }

    private func continueAreaSelection() {

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        selectionCoordinator = SelectionCoordinator()

        selectionCoordinator?.onSelectionComplete = { [weak self] globalRect in
            guard let self = self else { return }
            let rectToCapture = globalRect
            self.closeAllWindows()

            // Minimal delay for windows to close - 50ms is enough
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.captureArea(rect: rectToCapture)
            }
        }

        selectionCoordinator?.onCancel = { [weak self] in
            self?.closeAllWindows()
        }

        for screen in screens {
            let window = SelectionWindow(screen: screen, coordinator: selectionCoordinator!)
            selectionWindows.append(window)
        }

        // Register escape hotkey via HotkeyManager
        hotkeyManager?.onEscape = { [weak self] in
            self?.closeAllWindows()
        }
        hotkeyManager?.registerEscapeHotkey()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.closeAllWindows()
                }
                return nil
            }
            return event
        }

        // Force app activation
        NSApp.activate(ignoringOtherApps: true)

        for window in selectionWindows {
            window.orderFrontRegardless()
        }

        // Determine which window should be key based on mouse location
        let mouseLocation = NSEvent.mouseLocation
        let keyWindow: SelectionWindow?
        if let windowUnderMouse = selectionWindows.first(where: { $0.targetScreen.frame.contains(mouseLocation) }) {
            keyWindow = windowUnderMouse
        } else if let mainWindow = selectionWindows.first(where: { $0.targetScreen == NSScreen.main }) {
            keyWindow = mainWindow
        } else {
            keyWindow = selectionWindows.first
        }

        // Make the window key and force first responder
        if let window = keyWindow {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
    }

    private func closeAllWindows() {
        // Unregister escape hotkey
        hotkeyManager?.unregisterEscapeHotkey()
        hotkeyManager?.onEscape = nil

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        selectionCoordinator?.cleanup()
        selectionCoordinator = nil

        for window in selectionWindows {
            window.orderOut(nil)
            window.close()
        }
        selectionWindows.removeAll()
    }

    func captureArea(rect: NSRect) {
        // Gather screen info on main thread
        let centerPoint = NSPoint(x: rect.midX, y: rect.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(centerPoint) }) ?? NSScreen.main else {
            showAlert(message: "No screen found for selection")
            return
        }

        let scaleFactor = screen.backingScaleFactor
        let screenFrame = screen.frame
        let screenDisplayID = screen.displayID

        let localRect = NSRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: rect.origin.y - screenFrame.origin.y,
            width: rect.width,
            height: rect.height
        )

        let captureRect = CGRect(
            x: localRect.origin.x * scaleFactor,
            y: (screenFrame.height - localRect.origin.y - localRect.height) * scaleFactor,
            width: localRect.width * scaleFactor,
            height: localRect.height * scaleFactor
        )

        // Read settings on main thread before dispatching
        let autoCopyToClipboard = UserDefaults.standard.object(forKey: "autoCopyToClipboard") as? Bool ?? true
        let playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        let recognitionLanguage = UserDefaults.standard.string(forKey: "recognitionLanguage") ?? "en-US"
        let lineAwareOCR = UserDefaults.standard.object(forKey: "lineAwareOCR") as? Bool ?? true
        let ocrAccuracy = UserDefaults.standard.string(forKey: "ocrAccuracy") ?? "accurate"
        let useLanguageCorrection = UserDefaults.standard.object(forKey: "useLanguageCorrection") as? Bool ?? false

        // Perform entire capture and OCR pipeline on background thread
        // Use .utility priority (below default) to avoid priority inversion with SCScreenshotManager
        Task.detached(priority: .utility) { [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                guard let display = content.displays.first(where: { $0.displayID == screenDisplayID }) ?? content.displays.first else {
                    await self?.handleCaptureError(.noDisplay)
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width) * Int(scaleFactor)
                config.height = Int(display.height) * Int(scaleFactor)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                let fullImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                guard let croppedImage = fullImage.cropping(to: captureRect) else {
                    await self?.handleCaptureError(.cropFailed)
                    return
                }

                // Perform OCR
                let options = OCROptions(
                    languages: [recognitionLanguage],
                    automaticallyDetectsLanguage: true,
                    usesLanguageCorrection: useLanguageCorrection,
                    recognitionLevel: ocrAccuracy == "fast" ? .fast : .accurate,
                    lineAware: lineAwareOCR
                )
                let extractedText = OCREngine().recognizeText(in: croppedImage, options: options)

                // Update UI on main thread
                await self?.handleCaptureResult(
                    text: extractedText,
                    autoCopy: autoCopyToClipboard,
                    playSound: playSound
                )

            } catch {
                await self?.handleCaptureError(.general(error))
            }
        }
    }

    private enum CaptureError {
        case noDisplay
        case cropFailed
        case general(Error)
    }

    private func handleCaptureError(_ error: CaptureError) {
        switch error {
        case .noDisplay:
            showAlert(message: "No display found")
        case .cropFailed:
            showAlert(message: "Failed to crop image")
        case .general(let err):
            if err.localizedDescription.contains("permission") ||
               err.localizedDescription.contains("denied") {
                showPermissionAlert()
            } else {
                showAlert(message: "Capture failed: \(err.localizedDescription)")
            }
        }
    }

    private func handleCaptureResult(text: String?, autoCopy: Bool, playSound: Bool) {
        if let text = text, !text.isEmpty {
            if autoCopy {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            lastExtractedText = text

            if playSound {
                NSSound(named: .init("Funk"))?.play()
            }

            showNotification(text: text, autoCopied: autoCopy)
        } else {
            showNotification(text: nil, autoCopied: false)
        }
    }

    private func showNotification(text: String?, autoCopied: Bool) {
        let content = UNMutableNotificationContent()
        if let text = text {
            content.title = autoCopied ? "Text Copied" : "Text Captured"
            let preview = text.count > 100 ? String(text.prefix(100)) + "..." : text
            content.body = preview
        } else {
            content.title = "No Text Found"
            content.body = "No text was detected in the selected area"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Screenshot Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
