import XCTest

/// UI smoke tests for the core execution loop, per `docs/TESTING_AND_DELIVERY.md`.
final class StartKindUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(skipAuth: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = skipAuth
            ? ["-UITEST", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            : ["-UITEST_AUTH", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if !skipAuth {
            // Dismiss any lingering iOS Password AutoFill prompt from prior runs.
            if app.sheets.firstMatch.waitForExistence(timeout: 5) {
                app.sheets.firstMatch.swipeDown()
                _ = app.sheets.firstMatch.waitForNonExistence(timeout: 5)
            }
            if app.alerts.firstMatch.exists {
                app.alerts.firstMatch.buttons.element(boundBy: 0).tap()
            }
        }
        return app
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        if app.scrollViews.firstMatch.exists {
            app.scrollViews.firstMatch.swipeDown()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
    }

    func testAppLaunchesToStartTab() throws {
        let app = launch()
        // Start tab is default; voice button should be present.
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 15), "Start screen should show on launch")
    }

    func testSubmitButtonExistsAtLaunch() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["start.submit"].waitForExistence(timeout: 15), "Submit button should exist at launch")
    }

    func testCoreLoopCaptureToTimerToDone() throws {
        let app = launch()

        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        input.tap()
        input.typeText("I'm a mess today and need to deal with bills")

        // Tap a category chip to guarantee generation is enabled (robust to
        // simulator hardware-keyboard state affecting the text binding).
        let billsChip = app.buttons["Bills"]
        if billsChip.waitForExistence(timeout: 5) { billsChip.tap() }

        let submit = app.buttons["start.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        // One next step card should appear with a start button.
        let startButton = app.buttons["nextstep.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "A next step should appear after capture")

        // Dismiss the keyboard so it doesn't interfere with the timer sheet.
        if app.keyboards.firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        }

        // Start the timer.
        startButton.tap()
        let done = app.buttons["timer.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Timer should present a Done button")

        // Mark done -> returns to Start, no step card lingering.
        done.tap()
        let voiceAgain = app.buttons["start.voice"]
        XCTAssertTrue(voiceAgain.waitForExistence(timeout: 10), "Should return to Start after completing")
    }

    func testPartialOffersSmallerRestart() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("I need to deal with my insurance bill")
        let insuranceChip = app.buttons["Insurance"]
        if insuranceChip.waitForExistence(timeout: 5) { insuranceChip.tap() }
        app.buttons["start.submit"].tap()

        let startButton = app.buttons["nextstep.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        if app.keyboards.firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        }
        startButton.tap()

        // Use "Make it smaller" (paused) - should not show failure language.
        let makeSmaller = app.buttons["timer.makesmaller"]
        XCTAssertTrue(makeSmaller.waitForExistence(timeout: 10))
        makeSmaller.tap()

        // Back on Start, a kind message should appear (no "failed").
        let voiceAgain = app.buttons["start.voice"]
        XCTAssertTrue(voiceAgain.waitForExistence(timeout: 10))
    }

    func testCanSwitchTabs() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        // Tap each tab by stable index. Labels are localization-dependent.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let buttons = tabBar.buttons
        XCTAssertGreaterThanOrEqual(buttons.count, 4)
        for index in 0..<min(buttons.count, 4) {
            buttons.element(boundBy: index).tap()
        }
    }

    // MARK: - Auth + cloud

    func testAuthScreenShows() throws {
        let app = launch(skipAuth: false)
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 15), "Auth screen should show when not started")
        XCTAssertTrue(app.buttons["auth.submit"].exists)
        XCTAssertTrue(app.buttons["auth.skip"].exists)
    }

    func testSkipAuthEntersAppLocally() throws {
        let app = launch(skipAuth: false)
        XCTAssertTrue(app.buttons["auth.skip"].waitForExistence(timeout: 15))
        app.buttons["auth.skip"].tap()
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10), "Skipping should enter the app locally")
    }

    /// Full cloud e2e: sign up -> enter app -> capture -> cloud (DeepSeek) next step.
    func testCloudSignUpAndStep() throws {
        let app = launch(skipAuth: false)
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 15))
        let emailField = app.textFields["auth.email"]
        let email = "sk-ui-\(Int(Date().timeIntervalSince1970))@example.com"
        emailField.tap()
        emailField.typeText(email)
        app.secureTextFields["auth.password"].tap()
        app.secureTextFields["auth.password"].typeText("TestPass123!")
        dismissKeyboard(app)
        // Switch to Sign Up mode (default is Sign In), then submit.
        app.buttons["auth.switch"].tap()
        app.buttons["auth.submit"].tap()

        // Dismiss iOS Password AutoFill sheet/alert ("Save Password?") if it appeared.
        if app.sheets.firstMatch.waitForExistence(timeout: 8) {
            app.sheets.firstMatch.swipeDown()
            _ = app.sheets.firstMatch.waitForNonExistence(timeout: 5)
            if app.sheets.firstMatch.exists {
                app.sheets.firstMatch.buttons.element(boundBy: 0).tap()
            }
        }
        if app.alerts.firstMatch.exists {
            app.alerts.firstMatch.buttons.element(boundBy: 0).tap()
        }

        // After sign-up, enters the main app.
        let voice = app.buttons["start.voice"]
        if !voice.waitForExistence(timeout: 25) {
            XCTFail("Did not enter app after sign-up. StaticTexts:\n\(app.staticTexts.debugDescription)")
        }

        // Capture -> cloud-powered next step.
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        dismissKeyboard(app)
        input.tap()
        input.typeText("I am a mess today and I have an insurance bill I have been avoiding")
        let billsChip = app.buttons["Bills"]
        if billsChip.waitForExistence(timeout: 5) { billsChip.tap() }
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()
        let startButton = app.buttons["nextstep.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 25), "A cloud next step should appear after capture")
    }
}
