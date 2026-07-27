//
//  ClipboardPanelController.swift
//  MiniMe
//

import SwiftUI

@MainActor
final class ClipboardPanelController: ObservableObject {

    static let panelSize = CGSize(width: 460, height: 520)

    private var panel: KeyablePanel?
    private var clickOutsideMonitor: Any?
    private var previousApp: NSRunningApplication?

    var isVisible: Bool { panel?.isVisible == true }

    func toggle(
        store: ClipboardStore,
        settings: SettingsManager,
        monitor: ClipboardMonitor,
        onOpenSettings: @escaping () -> Void
    ) {
        if isVisible {
            close()
        } else {
            show(store: store, settings: settings, monitor: monitor, onOpenSettings: onOpenSettings)
        }
    }

    private func show(
        store: ClipboardStore,
        settings: SettingsManager,
        monitor: ClipboardMonitor,
        onOpenSettings: @escaping () -> Void
    ) {
        // Captured BEFORE MiniMe activates itself — otherwise the app we need to
        // paste back into has already been displaced.
        previousApp = NSWorkspace.shared.frontmostApplication

        let view = ClipboardPickerView(
            store: store,
            isEnabled: settings.clipboardHistoryEnabled,
            onSelect: { [weak self] entry in
                self?.select(entry, store: store, settings: settings, monitor: monitor)
            },
            onClose: { [weak self] in self?.close() },
            onOpenSettings: { [weak self] in
                self?.close()
                onOpenSettings()
            }
        )

        let panel = KeyablePanel(contentViewController: NSHostingController(rootView: view))
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false

        // Recomputed on every open, so the picker follows the user between displays.
        if let screen = ActiveScreenResolver.activeScreen() {
            panel.setFrame(
                ActiveScreenResolver.centeredRect(size: Self.panelSize, in: screen.visibleFrame),
                display: true
            )
        }

        self.panel = panel

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                DispatchQueue.main.async { self.close() }
            }
        }

        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func select(
        _ entry: ClipboardEntry,
        store: ClipboardStore,
        settings: SettingsManager,
        monitor: ClipboardMonitor
    ) {
        guard PasteService.shared.writeToPasteboard(entry, store: store) else {
            NSSound.beep()
            return
        }

        // Our own write must not come back as a new history entry.
        monitor.acknowledgeSelfWrite()

        let target = previousApp
        close()

        if PasteService.PickBehavior.from(rawValue: settings.clipboardPickBehavior) == .copyAndPaste {
            PasteService.shared.paste(into: target)
        }
    }

    func close() {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        clickOutsideMonitor = nil
        panel?.close()
        panel = nil
    }
}
