//
//  KeyablePanel.swift
//  MiniMe
//

import AppKit

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
