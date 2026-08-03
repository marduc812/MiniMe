//
//  ToolToggleUITests.swift
//  MiniMeUITests
//

import XCTest

/// Covers what unit tests can't reach: that the Tools section renders, and that
/// switching a tool off actually removes it from the menu bar menu and hides its
/// Settings tab.
///
/// MiniMe is an accessory app with no ordinary window, so ⌘, does nothing until
/// the status item menu has been opened. Everything here is driven through the
/// status item, the way a user does it.
final class ToolToggleUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = .miniMe()
        app.launch()
        XCTAssertTrue(app.statusItems.firstMatch.waitForExistence(timeout: 10),
                      "MiniMe's status item never appeared")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Driving helpers

    private func openStatusMenu() {
        app.statusItems.firstMatch.click()
        XCTAssertTrue(app.menuItems["Quit"].waitForExistence(timeout: 5),
                      "status item menu did not open")
    }

    private func dismissMenu() {
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
    }

    private func openSettings() -> XCUIElement {
        openStatusMenu()
        app.menuItems["Settings..."].click()
        let window = app.windows["Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Settings window did not open")
        return window
    }

    private func closeSettings() {
        app.typeKey("w", modifierFlags: .command)
    }

    /// Flips a tool's switch in General and closes Settings.
    private func setTool(_ tool: String, on: Bool) {
        let window = openSettings()
        let toggle = window.switches["tool-toggle-\(tool)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "no Tools switch for \(tool)")
        if (toggle.value as? Int == 1) != on {
            toggle.click()
        }
        closeSettings()
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: - Tests

    @MainActor
    func testToolsSectionListsEveryTool() throws {
        let window = openSettings()

        for tool in ["capture", "typeIt", "clipboard", "moveMouse", "preventSleep"] {
            XCTAssertTrue(
                window.switches["tool-toggle-\(tool)"].waitForExistence(timeout: 5),
                "Tools section is missing a switch for \(tool)"
            )
        }
        closeSettings()
    }

    /// The headline behaviour: a tool switched off leaves the menu bar menu.
    @MainActor
    func testDisablingAToolRemovesItFromTheMenuBarMenu() throws {
        openStatusMenu()
        XCTAssertTrue(app.menuItems["Clipboard"].exists,
                      "precondition: Clipboard is in the menu while the tool is on")
        dismissMenu()

        setTool("clipboard", on: false)

        openStatusMenu()
        XCTAssertFalse(app.menuItems["Clipboard"].exists,
                       "Clipboard should be gone from the menu once switched off")
        XCTAssertTrue(app.menuItems["Capture"].exists,
                      "other tools should be unaffected")
        dismissMenu()

        // Restore — this runs against the user's real preferences.
        setTool("clipboard", on: true)
        openStatusMenu()
        XCTAssertTrue(app.menuItems["Clipboard"].exists,
                      "Clipboard should return when switched back on")
        dismissMenu()
    }

    @MainActor
    func testDisablingAToolHidesItsSettingsTab() throws {
        var window = openSettings()
        XCTAssertTrue(window.buttons["Mouse"].exists,
                      "precondition: Mouse tab is visible while the tool is on")

        let toggle = window.switches["tool-toggle-moveMouse"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()

        XCTAssertTrue(waitForDisappearance(of: window.buttons["Mouse"]),
                      "Mouse tab should disappear when the tool is switched off")

        // Restore.
        toggle.click()
        XCTAssertTrue(window.buttons["Mouse"].waitForExistence(timeout: 5),
                      "Mouse tab should come back when switched on")
        closeSettings()

        // Guard against leaving the user's preferences flipped.
        window = openSettings()
        XCTAssertEqual(window.switches["tool-toggle-moveMouse"].value as? Int, 1)
        closeSettings()
    }

    @MainActor
    func testDisablingAToolHidesItsShortcutsRow() throws {
        let window = openSettings()

        let toggle = window.switches["tool-toggle-capture"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()

        window.buttons["Shortcuts"].click()
        XCTAssertTrue(
            waitForDisappearance(of: window.staticTexts["Capture screen area"]),
            "a disabled tool should not list a shortcut that no longer fires"
        )

        // Restore.
        window.buttons["General"].click()
        let restored = window.switches["tool-toggle-capture"]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        restored.click()
        closeSettings()
    }
}
