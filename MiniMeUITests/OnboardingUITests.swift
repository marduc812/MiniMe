//
//  OnboardingUITests.swift
//  MiniMeUITests
//

import XCTest

/// Covers what unit tests can't reach: that the setup deck actually renders a
/// slide per tool, and that a switch flipped inside it survives closing the
/// window early.
///
/// The wizard is reached through Settings › About › Run Setup Again rather than
/// by faking a first launch, so the test drives the same path a user does.
final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    private let toolIdentifiers = ["capture", "clipboard", "moveMouse", "preventSleep", "paper"]

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

    private func openSettings() -> XCUIElement {
        app.statusItems.firstMatch.click()
        XCTAssertTrue(app.menuItems["Quit"].waitForExistence(timeout: 5),
                      "status item menu did not open")
        app.menuItems["Settings..."].click()
        let window = app.windows["Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Settings window did not open")
        return window
    }

    private func openWizard() -> XCUIElement {
        let settings = openSettings()
        settings.buttons["About"].click()

        let runAgain = settings.buttons["Run Setup Again"]
        XCTAssertTrue(runAgain.waitForExistence(timeout: 5),
                      "About tab has no Run Setup Again button")
        runAgain.click()

        let wizard = app.windows["Welcome to MiniMe"]
        XCTAssertTrue(wizard.waitForExistence(timeout: 5), "setup window did not open")
        return wizard
    }

    /// Reads a tool's switch from Settings › General, leaving Settings open.
    private func toolSwitchInSettings(_ tool: String) -> XCUIElement {
        let settings = app.windows["Settings"]
        settings.buttons["General"].click()
        let toggle = settings.switches["tool-toggle-\(tool)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "no Tools switch for \(tool)")
        return toggle
    }

    // MARK: - Tests

    @MainActor
    func testTheDeckHasASlideForEveryTool() throws {
        let wizard = openWizard()

        // Slide 1 is the welcome; the tool slides follow in `Tool.allCases` order.
        for tool in toolIdentifiers {
            wizard.buttons["Next"].click()
            XCTAssertTrue(
                wizard.switches["onboarding-toggle-\(tool)"].waitForExistence(timeout: 5),
                "no slide reached for \(tool)"
            )
        }

        // One more Next lands on the summary, where the button becomes Done.
        wizard.buttons["Next"].click()
        XCTAssertTrue(wizard.buttons["Done"].waitForExistence(timeout: 5),
                      "the last slide should offer Done rather than Next")
        wizard.buttons["Done"].click()

        XCTAssertTrue(waitForDisappearance(of: wizard), "Done should close the setup window")
        app.windows["Settings"].typeKey("w", modifierFlags: .command)
    }

    /// The headline behaviour of the early-close decision: switches write
    /// through immediately, so closing the window mid-deck keeps the choice.
    @MainActor
    func testAChoiceMadeBeforeAnEarlyCloseIsKept() throws {
        let wizard = openWizard()

        wizard.buttons["Next"].click()
        let captureToggle = wizard.switches["onboarding-toggle-capture"]
        XCTAssertTrue(captureToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(captureToggle.value as? Int, 1,
                       "precondition: Capture starts enabled")

        captureToggle.click()

        // Close on the Capture slide, well short of the end.
        wizard.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(waitForDisappearance(of: wizard))

        XCTAssertEqual(toolSwitchInSettings("capture").value as? Int, 0,
                       "a switch flipped in the wizard should survive an early close")

        // Restore — this runs against the user's real preferences.
        toolSwitchInSettings("capture").click()
        XCTAssertEqual(toolSwitchInSettings("capture").value as? Int, 1)
        app.windows["Settings"].typeKey("w", modifierFlags: .command)
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
