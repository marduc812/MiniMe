//
//  XCUIApplication+MiniMe.swift
//  MiniMeUITests
//

import XCTest

extension XCUIApplication {

    /// Must match `SingleInstanceGuard.uiTestLaunchArgument`. A UI test target
    /// can't import the app module, so the string is spelled out on both sides;
    /// `theUITestFlagIsTheOneTheUITestsPass` in `SingleInstanceGuardTests` pins
    /// the app's half to this same literal.
    private static let uiTestLaunchArgument = "MINIME_UI_TESTING"

    /// MiniMe with the single-instance guard switched off.
    ///
    /// The guard exits a second copy at launch, and it can't tell the app under
    /// test apart from an ordinary launch — so without the flag every UI test on
    /// a machine already running MiniMe waits out its timeout on a process that
    /// quit before the runner reached it. Build every `XCUIApplication` here.
    static func miniMe() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(uiTestLaunchArgument)
        return app
    }
}
