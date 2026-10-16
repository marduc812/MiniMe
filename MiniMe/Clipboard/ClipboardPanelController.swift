//
//  ClipboardPanelController.swift
//  MiniMe
//

import SwiftUI

@MainActor
final class ClipboardPresentation: ObservableObject {
    @Published var isPresented = false
}

@MainActor
final class ClipboardPanelController: ObservableObject {

    static let panelSize = CGSize(width: 720, height: 500)

    private var panel: KeyablePanel?
    private var clickOutsideMonitor: Any?
    private var previousApp: NSRunningApplication?
    private let presentation = ClipboardPresentation()

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

        if panel == nil {
            panel = makePanel(store: store, settings: settings, monitor: monitor,
                              onOpenSettings: onOpenSettings)
        }
        guard let panel else { return }

        // Recomputed on every open, so the picker follows the user between displays.
        if let screen = ActiveScreenResolver.activeScreen() {
            panel.setFrame(
                ActiveScreenResolver.centeredRect(size: Self.panelSize, in: screen.visibleFrame),
                display: false
            )
        }
        presentation.isPresented = true

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

    private func makePanel(
        store: ClipboardStore,
        settings: SettingsManager,
        monitor: ClipboardMonitor,
        onOpenSettings: @escaping () -> Void
    ) -> KeyablePanel {
        let view = ClipboardPickerView(
            store: store,
            settings: settings,
            presentation: presentation,
            onSelect: { [weak self] entry in
                self?.select(entry, store: store, settings: settings, monitor: monitor)
            },
            onClose: { [weak self] in self?.close() },
            onOpenSettings: { [weak self] in
                self?.close()
                onOpenSettings()
            }
        )

        // Configure the final window before hosting SwiftUI, avoiding a second
        // layout caused by changing the style of an already populated window.
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false

        panel.contentViewController = NSHostingController(rootView: view)
        return panel
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
        presentation.isPresented = false
        panel?.orderOut(nil)
    }
}
