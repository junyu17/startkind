import XCTest

/// UI smoke tests for the core execution loop, per `docs/TESTING_AND_DELIVERY.md`.
@MainActor
final class StartKindUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(skipAuth: Bool = true, plus: Bool = false, onboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = skipAuth
            ? ["-UITEST", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            : ["-UITEST_AUTH", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if plus { arguments.append("-UITEST_PLUS") }
        if onboarding { arguments.append("-UITEST_ONBOARDING") }
        app.launchArguments = arguments
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
        let done: XCUIElement
        if app.buttons["keyboard.done"].exists {
            done = app.buttons["keyboard.done"]
        } else if app.buttons["admin.keyboard.done"].exists {
            done = app.buttons["admin.keyboard.done"]
        } else {
            done = app.buttons["onboarding.keyboard.done"]
        }
        if done.waitForExistence(timeout: 2) {
            done.tap()
            if app.keyboards.firstMatch.waitForNonExistence(timeout: 5) { return }
        }
        if app.scrollViews.firstMatch.exists {
            app.scrollViews.firstMatch.swipeDown()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
    }

    func testFirstRunSetupRequiresNameAndDifficulty() throws {
        let app = launch(onboarding: true)

        XCTAssertTrue(app.staticTexts["What should we call you?"].waitForExistence(timeout: 15))
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.exists)
        XCTAssertFalse(app.buttons["onboarding.name.next"].isEnabled)
        focusAndType(app, name, "Sam")
        dismissKeyboard(app)
        XCTAssertTrue(app.buttons["onboarding.name.next"].isEnabled)
        app.buttons["onboarding.name.next"].tap()

        let difficulty = app.buttons["onboarding.difficulty.tasks_too_big"]
        XCTAssertTrue(difficulty.waitForExistence(timeout: 10))
        difficulty.tap()
        XCTAssertTrue(app.buttons["onboarding.finish"].isEnabled)
        app.buttons["onboarding.finish"].tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Hi, Sam."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["If the step feels too big, tap Make it smaller."].exists)
    }

    func testDefaultUITESTBypassesFirstRunSetup() throws {
        let app = launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.textFields["onboarding.name"].exists)
    }

    private func openMoreWays(_ app: XCUIApplication) {
        let scanGroup = app.buttons["start.moreWays.scan"].firstMatch
        if scanGroup.exists { return }
        let disclosure = app.buttons["start.moreWays"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 15), "More ways section should be present")
        scrollToHittable(app, disclosure, label: "More ways disclosure")
        disclosure.tap()
        XCTAssertTrue(scanGroup.waitForExistence(timeout: 5), "More ways section should expand")
    }

    private func scrollToHittable(_ app: XCUIApplication, _ element: XCUIElement, label: String) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(label) should be hittable")
    }

    private func expandMoreWaysGroup(_ app: XCUIApplication, _ groupID: String, childID: String) {
        let group = app.buttons[groupID].firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 10), "More ways group \(groupID) should exist")
        let child = app.descendants(matching: .any)[childID]
        if !child.exists {
            scrollToHittable(app, group, label: "More ways group \(groupID)")
            group.tap()
        }
        XCTAssertTrue(child.waitForExistence(timeout: 10), "\(childID) should appear after expanding \(groupID)")
        scrollToHittable(app, child, label: "More ways child \(childID)")
    }

    private func expandNextStepMoreActions(_ app: XCUIApplication) {
        let disclosure = app.buttons["nextstep.moreActions"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 10), "Next-step More actions disclosure should exist")
        let share = app.buttons["nextstep.share"].firstMatch
        if !share.exists {
            scrollToHittable(app, disclosure, label: "Next-step More actions disclosure")
            disclosure.tap()
        }
        XCTAssertTrue(share.waitForExistence(timeout: 10), "Next-step secondary actions should appear")
        scrollToHittable(app, share, label: "Next-step secondary actions")
    }

    /// Tap a field and wait for it to actually hold keyboard focus before typing.
    /// Typing into a field that is still animating in throws "neither element nor
    /// any descendant has keyboard focus".
    private func focusAndType(_ app: XCUIApplication, _ field: XCUIElement, _ text: String) {
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) {
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Field should take keyboard focus")
        }
        field.typeText(text)
    }

    func testDisplaySettingsOfferThemeAndTextSize() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()

        let theme = app.segmentedControls["settings.theme"]
        XCTAssertTrue(theme.waitForExistence(timeout: 10), "Theme control should be in Settings")
        XCTAssertEqual(theme.buttons.count, 3, "System / Light / Dark")

        let textSize = app.descendants(matching: .any)["settings.textSize"]
        XCTAssertTrue(textSize.waitForExistence(timeout: 5), "Text size control should be in Settings")

        // Choosing Dark must stick, not silently revert.
        theme.buttons["Dark"].tap()
        XCTAssertTrue(theme.buttons["Dark"].isSelected)

        textSize.tap()
        for option in ["Smaller", "Small", "Standard", "Large", "Larger", "Largest"] {
            XCTAssertTrue(app.buttons[option].waitForExistence(timeout: 5), "Text size menu should include \(option)")
        }
        app.buttons["Smaller"].tap()
        XCTAssertTrue(app.staticTexts["settings.textSize.sample"].exists, "A live sample should show the chosen size")
    }

    func testStartRendersInLargestTextDarkModeAndSimplifiedChinese() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()

        let theme = app.segmentedControls["settings.theme"]
        XCTAssertTrue(theme.waitForExistence(timeout: 10))
        theme.buttons["Dark"].tap()
        let textSize = app.descendants(matching: .any)["settings.textSize"]
        XCTAssertTrue(textSize.waitForExistence(timeout: 10))
        textSize.tap()
        XCTAssertTrue(app.buttons["Largest"].waitForExistence(timeout: 5))
        app.buttons["Largest"].tap()

        let language = app.descendants(matching: .any)["settings.language"]
        XCTAssertTrue(language.waitForExistence(timeout: 10), "Language picker should be reachable")
        language.tap()
        let chinese = app.buttons["简体中文"]
        XCTAssertTrue(chinese.waitForExistence(timeout: 10), "Simplified Chinese option should be visible")
        chinese.tap()

        app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
        for id in ["start.voice", "start.input", "global.stuck", "start.moreWays"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 10), "\(id) should render in Chinese at largest text")
        }
        XCTAssertFalse(app.descendants(matching: .any)["start.autopilot"].exists)
    }

    private func openSettings() -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        let upgrade = app.buttons["settings.subscription.upgrade"].firstMatch
        for _ in 0..<8 where !(upgrade.exists && upgrade.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(upgrade.exists && upgrade.isHittable, "Free upgrade action should be reachable")
        upgrade.tap()
        return app
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

    func testGenericTaskShowsACompleteNextActionWithoutRequestingSecondInput() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        focusAndType(app, input, "I need to sort out a complicated personal project")
        app.buttons["start.submit"].tap()

        XCTAssertTrue(app.staticTexts["Your next step"].waitForExistence(timeout: 10))
        let title = app.descendants(matching: .any)["nextstep.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.label.lowercased().contains("sort out"))
        let action = app.descendants(matching: .any)["nextstep.action"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertTrue(action.label.lowercased().contains("personal project"))
        XCTAssertFalse(action.label.lowercased().contains("say or write"))
    }

    func testRepairCaptureRendersFanSpecificNextStepWithoutGenericFallback() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        focusAndType(app, input, "fix the fan")
        dismissKeyboard(app)

        let submit = app.buttons["start.submit"]
        XCTAssertTrue(submit.isEnabled, "Capture submit should be enabled")
        submit.tap()

        let title = app.descendants(matching: .any)["nextstep.title"]
        let action = app.descendants(matching: .any)["nextstep.action"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "A next-step title should render")
        XCTAssertTrue(action.waitForExistence(timeout: 10), "A next-step action should render")
        XCTAssertTrue(
            "\(title.label) \(action.label)".lowercased().contains("fan"),
            "The rendered repair step should mention the fan"
        )
        XCTAssertFalse(
            app.staticTexts["Open where this task lives"].exists,
            "Repair capture should not use the generic fallback"
        )
    }

    func testUnseenIntentCaptureKeepsObjectSpecificActionThroughAppPath() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        focusAndType(app, input, "calibrate the telescope")
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()

        let title = app.descendants(matching: .any)["nextstep.title"]
        let action = app.descendants(matching: .any)["nextstep.action"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "A next-step title should render")
        XCTAssertTrue(action.waitForExistence(timeout: 10), "A next-step action should render")
        XCTAssertTrue("\(title.label) \(action.label)".lowercased().contains("telescope"))
        XCTAssertTrue("\(title.label) \(action.label)".lowercased().contains("calibrate"))
        XCTAssertTrue(action.label.lowercased().contains("search"))
        XCTAssertTrue(action.label.lowercased().contains("official guide"))
        XCTAssertFalse(app.staticTexts["Open where this task lives"].exists)
    }

    func testVoiceTapDoesNotTerminateApp() throws {
        let app = launch()
        addUIInterruptionMonitor(withDescription: "Speech and microphone permissions") { alert in
            for label in ["Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        let voice = app.buttons["start.voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 15), "Voice button should exist")
        voice.tap()

        // A first launch can show speech and microphone prompts back to back.
        // Interacting with the app gives XCTest's interruption monitor a chance
        // to accept each system-owned alert.
        for _ in 0..<3 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            sleep(1)
        }

        let speechError = app.descendants(matching: .any)["start.error"]
        XCTAssertTrue(
            voice.label.contains("Listening") || speechError.waitForExistence(timeout: 10),
            "Voice should either remain listening or show why speech recognition could not continue"
        )

        // Allow the realtime audio tap to receive buffers before checking the
        // process. A foreground state alone does not prove the main run loop
        // is still usable, so interact with the capture field afterward.
        sleep(8)
        XCTAssertEqual(app.state, .runningForeground, "Voice tap should not crash or terminate the app")

        let stuck = app.buttons["global.stuck"]
        XCTAssertTrue(stuck.waitForExistence(timeout: 10), "Other Start controls should remain available after voice tap")
        XCTAssertTrue(stuck.isHittable, "Other Start controls should remain tappable after voice tap")
        stuck.tap()
        XCTAssertTrue(
            app.buttons["nextstep.start"].waitForExistence(timeout: 10),
            "A second action should still produce a next step while voice capture is active"
        )

        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.buttons["start.voice"].waitForExistence(timeout: 15),
            "The Start screen should render after terminating during a voice session and relaunching"
        )
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Relaunch should not leave a blank screen")
    }

    func testSubmittingCaptureStopsActiveVoiceCapture() throws {
        let app = launch()
        addUIInterruptionMonitor(withDescription: "Speech and microphone permissions") { alert in
            for label in ["Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        let voice = app.buttons["start.voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 15), "Voice button should exist")
        voice.tap()

        var listening = false
        for _ in 0..<10 {
            if voice.label.contains("Listening") {
                listening = true
                break
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
            sleep(1)
        }
        guard listening else {
            throw XCTSkip("Speech capture was unavailable in this simulator")
        }

        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Capture field should exist")
        focusAndType(app, input, "fix the fan")
        dismissKeyboard(app)

        let submit = app.buttons["start.submit"]
        XCTAssertTrue(submit.isEnabled, "Capture submit should be enabled")
        scrollToHittable(app, submit, label: "Capture submit")
        submit.tap()

        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Submit should generate a next step")
        XCTAssertFalse(voice.label.contains("Listening"), "Submit should stop listening")
        XCTAssertFalse(voice.label.contains("Preparing"), "Submit should stop speech preparation")
    }

    func testFriendCoStartEntryVisibleAfterInput() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.costart", childID: "start.costart.friend")
        input.tap()
        input.typeText("I need someone to sit with me while I start my bill")
        let friendInvite = app.buttons["start.costart.friend"]
        XCTAssertTrue(friendInvite.waitForExistence(timeout: 5), "Friend co-start should be visible from Start")
        XCTAssertTrue(friendInvite.isEnabled, "Friend co-start should enable after entering a step")
    }

    func testStartKeyboardDoneDismissesWhenVisible() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        input.tap()
        input.typeText("pay the bill")
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.buttons["keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Keyboard Done button should exist")
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Keyboard should dismiss")
    }

    func testRoomCodeFieldLimitsToSixDigits() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.costart", childID: "start.join.code")
        let codeField = app.textFields["start.join.code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 15), "Room code field should exist")
        codeField.tap()
        codeField.typeText("12345678")
        XCTAssertEqual((codeField.value as? String) ?? "", "123456")
        XCTAssertTrue(app.buttons["start.join.submit"].exists, "Join button should exist")
    }

    func testCategorySelectionShowsFeedback() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.match", childID: "energy.low")
        let billsChip = app.buttons["Bills"]
        XCTAssertTrue(billsChip.waitForExistence(timeout: 15), "Bills chip should exist")
        billsChip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["start.category.selected"].waitForExistence(timeout: 5), "Category selection should show visible feedback")
    }

    func testFrictionForecastCreatesStartableStep() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        input.tap()
        input.typeText("I need the password before I can pay this bill")
        dismissKeyboard(app)

        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.match", childID: "energy.low")

        let forecast = app.buttons["frictionForecast.apply"]
        XCTAssertTrue(forecast.waitForExistence(timeout: 10), "Friction Forecast should appear for a likely blocker")
        forecast.tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Friction Forecast should create a startable step")
    }

    func testKindStartAdminReaderParsesBillText() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.admin")
        let adminButton = app.buttons["start.kind.admin"].firstMatch
        XCTAssertTrue(adminButton.waitForExistence(timeout: 15), "Kind Start admin entry should exist")
        adminButton.tap()

        let adminInput = app.textViews["admin.input"]
        XCTAssertTrue(adminInput.waitForExistence(timeout: 10), "Admin Reader input should exist")
        focusAndType(app, adminInput, "Invoice bill $42 due 12/15/2026 pay at https://example.com")
        dismissKeyboard(app)

        let parse = app.buttons["admin.parse"]
        XCTAssertTrue(parse.waitForExistence(timeout: 5), "Admin parse button should exist")
        parse.tap()
        XCTAssertTrue(app.descendants(matching: .any)["admin.result"].waitForExistence(timeout: 10), "Admin result should appear")
        let startTimer = app.buttons["admin.startTimer"]
        XCTAssertTrue(startTimer.exists, "Admin Reader should produce a startable timer step")
        scrollToHittable(app, startTimer, label: "Admin Reader start timer")
        startTimer.tap()
        XCTAssertTrue(app.buttons["timer.done"].waitForExistence(timeout: 10), "The first tap should open a populated timer, not a blank sheet")
    }

    func testPhotoToStepAndExecutionModelEntriesVisible() throws {
        let app = launch(plus: true)
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.photo")
        XCTAssertTrue(app.descendants(matching: .any)["start.kindStart"].waitForExistence(timeout: 15), "Kind Start panel should exist")
        XCTAssertTrue(app.descendants(matching: .any)["start.kind.photo"].exists, "Photo-to-step entry should exist")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["patterns.recommendation"].waitForExistence(timeout: 10), "Actionable recommendation should be visible")
        let advanced = app.buttons["patterns.advanced"].firstMatch
        XCTAssertTrue(advanced.waitForExistence(timeout: 10), "Plus advanced disclosure should be visible")
        for _ in 0..<8 where !advanced.isHittable { app.swipeUp() }
        XCTAssertTrue(advanced.isHittable)
        advanced.tap()
        XCTAssertTrue(app.descendants(matching: .any)["patterns.model.summary"].waitForExistence(timeout: 10), "Personal Execution Model should appear after expansion")
        XCTAssertTrue(app.descendants(matching: .any)["startProfile.card"].exists, "Start Profile should be visible")
    }

    func testPhotoEntryOpensDismissibleScanChoices() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.photo")
        let photoEntry = app.buttons["start.kind.photo"].firstMatch
        XCTAssertTrue(photoEntry.waitForExistence(timeout: 15), "Photo entry should exist")
        photoEntry.tap()

        XCTAssertTrue(app.descendants(matching: .any)["admin.photo.source"].waitForExistence(timeout: 10), "Photo flow should begin with visible source choices")
        XCTAssertTrue(app.buttons["admin.camera"].waitForExistence(timeout: 10), "Camera scan choice should be visible")
        XCTAssertTrue(app.buttons["admin.photoLibrary"].exists, "Photo or screenshot scan choice should be visible")
        XCTAssertTrue(app.buttons["admin.paste"].exists, "Pasted text should remain available from the source choice")
        XCTAssertFalse(app.textViews["admin.recognizedText"].exists, "Photo flow should wait for OCR before showing text review")
        XCTAssertFalse(app.buttons["admin.parse"].exists, "Find one step should wait for the image review stage")

        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Admin scan screen should be dismissible")
        close.tap()
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10), "Closing scan screen should return to Start")
    }

    func testAutopilotCreatesOneNextStep() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.plan", childID: "start.autopilot")
        let autopilot = app.buttons["start.autopilot"].firstMatch
        XCTAssertTrue(autopilot.waitForExistence(timeout: 15), "Autopilot entry should exist")
        autopilot.tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Autopilot should create a startable next step")
    }

    func testUpcomingEventPrepSubmitCreatesVisibleStep() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.plan", childID: "calendarSoft.input")

        let input = app.textFields["calendarSoft.input"].exists
            ? app.textFields["calendarSoft.input"]
            : app.textViews["calendarSoft.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Upcoming event input should exist")
        focusAndType(app, input, "Pick up package")
        dismissKeyboard(app)

        let submit = app.buttons["calendarSoft.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10), "Upcoming event prep submit should exist")
        XCTAssertTrue(submit.isEnabled, "A non-empty upcoming event should be submittable")
        submit.tap()

        let nextStep = app.buttons["nextstep.start"]
        XCTAssertTrue(nextStep.waitForExistence(timeout: 10), "Event prep should create a next-step card")
        XCTAssertTrue(nextStep.isHittable, "Event prep should scroll the new next-step card into view")
    }

    func testNextStepMoreActionsRevealSecondaryOptions() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        input.tap()
        input.typeText("Review the bill at https://example.com")
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()

        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "A next step should appear")
        for id in ["nextstep.share", "nextstep.saveVault", "nextstep.showPlan", "nextstep.actionPrep", "nextstep.ladder", "nextstep.costart", "nextstep.moveOn"] {
            XCTAssertFalse(app.descendants(matching: .any)[id].exists, "\(id) should start behind More actions")
        }

        expandNextStepMoreActions(app)
        for id in ["nextstep.share", "nextstep.saveVault", "nextstep.showPlan", "nextstep.actionPrep", "nextstep.ladder", "nextstep.costart", "nextstep.moveOn"] {
            let action = app.descendants(matching: .any)[id]
            XCTAssertTrue(action.waitForExistence(timeout: 10), "\(id) should be discoverable after expanding More actions")
        }
        XCTAssertTrue(app.descendants(matching: .any)["nextstep.actionPrep"].exists, "Action Prep guidance should remain visible after expansion")
        XCTAssertTrue(app.buttons["nextstep.showPlan"].isEnabled)
        app.buttons["nextstep.showPlan"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["nextstep.plan"].waitForExistence(timeout: 10), "Show plan should reveal the plan text")

        app.buttons["nextstep.costart"].tap()
        XCTAssertTrue(app.buttons["costart.ai"].waitForExistence(timeout: 10), "Co-start should open its mode picker on the first tap")
        XCTAssertTrue(app.buttons["costart.friend"].exists, "Friend co-start should be available in the populated sheet")
    }

    func testQuietCoStartShowsReadyBeforeExplicitStart() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        focusAndType(app, input, "I need to deal with a bill")
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()

        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "A generated next step should appear")
        expandNextStepMoreActions(app)
        let coStart = app.buttons["nextstep.costart"]
        XCTAssertTrue(coStart.waitForExistence(timeout: 10), "Co-start action should appear for the generated step")
        scrollToHittable(app, coStart, label: "Co-start action")
        coStart.tap()

        let quiet = app.buttons["costart.ai"]
        XCTAssertTrue(quiet.waitForExistence(timeout: 10), "Quiet co-start should be available")
        quiet.tap()

        let stage = app.descendants(matching: .any)["costart.stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 10), "Co-start stage should be visible")
        XCTAssertTrue(stage.label.contains("Ready"), "Quiet co-start should show Ready before starting")
        XCTAssertFalse(
            app.descendants(matching: .any)["costart.countdown"].exists,
            "Quiet co-start should not show a countdown before Start 25 minutes"
        )

        let start = app.buttons["costart.start25"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Start 25 minutes should be available")
        start.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["costart.countdown"].waitForExistence(timeout: 10),
            "Quiet co-start should show a countdown after starting"
        )
    }

    func testStartLadderAndUrgentAdminEntriesWork() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.plan", childID: "start.autopilot")
        let autopilot = app.buttons["start.autopilot"].firstMatch
        XCTAssertTrue(autopilot.waitForExistence(timeout: 15))
        autopilot.tap()
        expandNextStepMoreActions(app)
        XCTAssertTrue(app.buttons["nextstep.ladder.2"].waitForExistence(timeout: 10), "Start Ladder should offer a two-minute version")
        app.buttons["nextstep.ladder.2"].tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Selected ladder version should remain startable")

        let admin = app.buttons["start.kind.admin"].firstMatch
        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.admin")
        XCTAssertTrue(admin.waitForExistence(timeout: 10))
        admin.tap()
        let input = app.textViews["admin.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("Final notice: your payment is due today.")
        dismissKeyboard(app)
        let urgentStart = app.buttons["urgentAdmin.start"]
        XCTAssertTrue(urgentStart.waitForExistence(timeout: 10), "Urgent admin mode should offer a neutral contact-first start")
        XCTAssertTrue(urgentStart.isEnabled)
    }

    func testRetentionControlsCreateStartableStep() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.match", childID: "energy.low")
        let energy = app.buttons["energy.overwhelmed"]
        XCTAssertTrue(energy.waitForExistence(timeout: 10), "Energy Match should be visible")
        energy.tap()

        let tabsPreset = app.buttons["frictionPreset.too_many_tabs"]
        XCTAssertTrue(tabsPreset.waitForExistence(timeout: 10), "Friction presets should be visible")
        tabsPreset.tap()

        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Friction preset should create a startable step")
        XCTAssertTrue(app.buttons["proof.started"].waitForExistence(timeout: 5), "Proof of Start should be available on a step")
        app.buttons["proof.started"].tap()

        let stuck = app.buttons["global.stuck"]
        XCTAssertTrue(stuck.waitForExistence(timeout: 10), "Global Stuck button should always be available")
        stuck.tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Stuck should keep a startable step ready")
    }

    func testPaywallShowsFreePlusComparison() throws {
        let app = openSettings()
        let comparison = app.staticTexts["Free vs Plus"]
        let annual = app.buttons["paywall.annual"]
        let monthly = app.buttons["paywall.monthly"]
        XCTAssertTrue(comparison.waitForExistence(timeout: 10), "Paywall should compare Free and Plus")
        XCTAssertTrue(annual.waitForExistence(timeout: 10), "Annual selector should exist")
        XCTAssertTrue(monthly.waitForExistence(timeout: 10), "Monthly selector should exist")
        let retry = app.buttons["paywall.products.retry"]
        let subscribe = app.buttons["paywall.subscribe"]
        if retry.exists {
            XCTAssertFalse(annual.isEnabled, "Unavailable annual plan must be disabled")
            XCTAssertFalse(monthly.isEnabled, "Unavailable monthly plan must be disabled")
            XCTAssertFalse(subscribe.exists, "A failed product load must not leave a dead subscribe CTA")
        } else {
            XCTAssertTrue(subscribe.waitForExistence(timeout: 10), "Loaded products must expose the subscribe action")
            XCTAssertTrue(annual.isEnabled)
            XCTAssertTrue(monthly.isEnabled)
        }
        XCTAssertTrue(app.buttons["paywall.privacy"].exists, "Privacy link should remain visible")
        XCTAssertTrue(app.buttons["paywall.terms"].exists, "Terms link should remain visible")
        XCTAssertLessThan(annual.frame.minY, comparison.frame.minY, "Annual selector should precede Free-vs-Plus comparison")
        XCTAssertLessThan(monthly.frame.minY, comparison.frame.minY, "Monthly selector should precede Free-vs-Plus comparison")
    }

    func testMoreWaysRevealsSecondaryOptions() throws {
        let app = launch()
        openMoreWays(app)
        XCTAssertFalse(app.descendants(matching: .any)["start.kind.admin"].exists, "Admin tools should stay collapsed")
        XCTAssertFalse(app.descendants(matching: .any)["start.costart.friend"].exists, "Co-start tools should stay collapsed")
        XCTAssertFalse(app.descendants(matching: .any)["start.costart.quiet"].exists, "Quiet co-start should stay collapsed")
        XCTAssertFalse(app.descendants(matching: .any)["energy.overwhelmed"].exists, "Match tools should stay collapsed")
        XCTAssertFalse(app.descendants(matching: .any)["start.autopilot"].exists, "Plan tools should stay collapsed")

        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.admin")
        XCTAssertTrue(app.descendants(matching: .any)["start.kind.photo"].exists, "Photo or screenshot scan should be in Scan or paste")
        XCTAssertTrue(app.textFields["adminInbox.input"].exists, "Tiny admin inbox should be in Scan or paste")
        XCTAssertFalse(app.buttons["start.templates"].exists, "Templates should not be in Scan or paste")
        XCTAssertFalse(app.buttons["start.vault"].exists, "Saved starts should not be in Scan or paste")

        expandMoreWaysGroup(app, "start.moreWays.reuse", childID: "start.templates")
        XCTAssertTrue(app.buttons["start.vault"].exists, "Saved starts should be in Reuse a start")
        XCTAssertTrue(app.descendants(matching: .any)["startScript.title"].exists, "Reusable scripts should be in Reuse a start")

        expandMoreWaysGroup(app, "start.moreWays.costart", childID: "start.costart.friend")
        XCTAssertTrue(app.buttons["start.costart.quiet"].exists, "Quiet co-start should be in Start with someone")
        XCTAssertTrue(app.buttons["start.join.submit"].exists, "Room code join should be in Co-start")

        expandMoreWaysGroup(app, "start.moreWays.match", childID: "energy.overwhelmed")
        XCTAssertTrue(app.buttons["frictionPreset.too_many_tabs"].exists, "Friction presets should be in Match how I feel")
        XCTAssertTrue(app.buttons["start.emergency"].exists, "Emergency start should be in Match how I feel")

        expandMoreWaysGroup(app, "start.moreWays.plan", childID: "start.autopilot")
        XCTAssertTrue(app.descendants(matching: .any)["calendarSoft.input"].exists, "Upcoming event prep should be in Plan ahead")
    }

    func testCoreLoopCaptureToTimerToDone() throws {
        let app = launch()

        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        input.tap()
        input.typeText("I'm a mess today and need to deal with bills")
        dismissKeyboard(app)

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
        XCTAssertTrue(app.buttons["savedStart.notNow"].waitForExistence(timeout: 10))
        app.alerts.firstMatch.buttons["savedStart.notNow"].firstMatch.tap()
        let voiceAgain = app.buttons["start.voice"]
        XCTAssertTrue(voiceAgain.waitForExistence(timeout: 10), "Should return to Start after completing")
    }

    func testCompletedStartCanBeSavedAndViewed() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        focusAndType(app, input, "I need to deal with my insurance bill")
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()

        let start = app.buttons["nextstep.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let done = app.buttons["timer.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()

        XCTAssertTrue(app.buttons["savedStart.save"].waitForExistence(timeout: 10))
        app.alerts.firstMatch.buttons["savedStart.save"].firstMatch.tap()
        let viewSaved = app.buttons["savedStart.view"]
        XCTAssertTrue(viewSaved.waitForExistence(timeout: 10))
        viewSaved.tap()

        XCTAssertTrue(app.navigationBars["Saved starts"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["vault.item"].waitForExistence(timeout: 10))
    }

    func testEquivalentSavedStartSuppressesCompletionPrompt() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        focusAndType(app, input, "I need to deal with my insurance bill")
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()

        let start = app.buttons["nextstep.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        expandNextStepMoreActions(app)
        XCTAssertTrue(app.buttons["nextstep.saveVault"].waitForExistence(timeout: 10))
        app.buttons["nextstep.saveVault"].tap()
        start.tap()
        XCTAssertTrue(app.buttons["timer.done"].waitForExistence(timeout: 10))
        app.buttons["timer.done"].tap()

        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["savedStart.save"].exists)
    }

    func testAdminCompletionOffersSavedStartPromptWithoutBlankDestination() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.admin")
        app.buttons["start.kind.admin"].tap()

        let adminInput = app.textViews["admin.input"]
        XCTAssertTrue(adminInput.waitForExistence(timeout: 10))
        focusAndType(app, adminInput, "Invoice bill $42 due 12/15/2026")
        dismissKeyboard(app)
        app.buttons["admin.parse"].tap()
        XCTAssertTrue(app.buttons["admin.startTimer"].waitForExistence(timeout: 10))
        app.buttons["admin.startTimer"].tap()
        XCTAssertTrue(app.buttons["timer.done"].waitForExistence(timeout: 10))
        app.buttons["timer.done"].tap()

        XCTAssertTrue(app.buttons["savedStart.save"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["admin.result"].exists)
        app.alerts.firstMatch.buttons["savedStart.notNow"].firstMatch.tap()
    }

    func testFrictionOnlyCompletionReturnsToNextRungInsteadOfDeletingTask() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        focusAndType(app, input, "I need to deal with my insurance bill")
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10))

        let stuck = app.buttons["global.stuck"]
        for _ in 0..<3 {
            for _ in 0..<8 where !stuck.isHittable { app.swipeDown() }
            XCTAssertTrue(stuck.isHittable, "I'm stuck should remain reachable while shrinking")
            stuck.tap()
        }
        XCTAssertTrue(app.staticTexts["Friction-only: set up"].waitForExistence(timeout: 10))

        let start = app.buttons["nextstep.start"]
        scrollToHittable(app, start, label: "Friction-only start")
        start.tap()
        let done = app.buttons["timer.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()

        XCTAssertTrue(app.staticTexts["Tiny: just open it"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["nextstep.start"].exists, "The task should continue at the next rung")
        XCTAssertTrue(app.staticTexts["Setup done. Here's the next small action."].exists)
        XCTAssertFalse(app.buttons["savedStart.save"].exists)
    }

    func testPartialOffersSmallerRestart() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("I need to deal with my insurance bill")
        dismissKeyboard(app)
        let insuranceChip = app.buttons["Insurance"]
        if insuranceChip.waitForExistence(timeout: 5) { insuranceChip.tap() }
        dismissKeyboard(app)
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
        XCTAssertFalse(app.buttons["savedStart.save"].exists)
    }

    func testInterruptedShowsBlockerPickerAndRecoveryBlocker() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("I need to deal with a bill but got interrupted")
        dismissKeyboard(app)
        let billsChip = app.buttons["Bills"]
        if billsChip.waitForExistence(timeout: 5) { billsChip.tap() }
        dismissKeyboard(app)
        app.buttons["start.submit"].tap()

        let startButton = app.buttons["nextstep.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        let interrupted = app.buttons["timer.interrupted"]
        XCTAssertTrue(interrupted.waitForExistence(timeout: 10))
        interrupted.tap()

        let needDocument = app.buttons["blocker.need_document"]
        XCTAssertTrue(needDocument.waitForExistence(timeout: 10))
        needDocument.tap()

        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["recover.blocker"].waitForExistence(timeout: 10), "Recover should show the saved blocker")
        let resume = app.buttons["recover.startTimer"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "Recovery start should exist")
        resume.tap()
        XCTAssertTrue(app.buttons["timer.done"].waitForExistence(timeout: 10), "Recovery should open a populated timer on the first tap")
    }

    func testInterruptedReturnNoteAppearsInRecovery() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists ? app.textFields["start.input"] : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("I need to handle an insurance form")
        dismissKeyboard(app)
        let insuranceChip = app.buttons["Insurance"]
        if insuranceChip.waitForExistence(timeout: 5) { insuranceChip.tap() }
        app.buttons["start.submit"].tap()

        let startButton = app.buttons["nextstep.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        let interrupted = app.buttons["timer.interrupted"]
        XCTAssertTrue(interrupted.waitForExistence(timeout: 10))
        interrupted.tap()

        let note = app.textFields["returnNote.input"].exists ? app.textFields["returnNote.input"] : app.textViews["returnNote.input"]
        XCTAssertTrue(note.waitForExistence(timeout: 10), "Return note field should appear")
        note.tap()
        note.typeText("Form is on page 2")
        let tooBig = app.buttons["blocker.too_big"]
        XCTAssertTrue(tooBig.waitForExistence(timeout: 10))
        tooBig.tap()

        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10))
        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["recover.returnNote"].waitForExistence(timeout: 10), "Recover should show the saved return note")
    }

    func testTemplatesShareAndVaultFlow() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.reuse", childID: "start.templates")
        let templates = app.buttons["start.templates"].firstMatch
        XCTAssertTrue(templates.waitForExistence(timeout: 15), "Templates entry should exist")
        templates.tap()

        let billTemplate = app.buttons["template.bill_anchor"]
        XCTAssertTrue(billTemplate.waitForExistence(timeout: 10), "Bill template should exist")
        billTemplate.tap()

        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Template should create a local next step")
        XCTAssertFalse(app.descendants(matching: .any)["nextstep.share"].exists, "Secondary card actions should start collapsed")
        expandNextStepMoreActions(app)
        XCTAssertTrue(app.buttons["nextstep.share"].exists, "Start card share button should exist after expanding More actions")
        XCTAssertTrue(app.descendants(matching: .any)["nextstep.moreActions"].exists, "More actions disclosure should remain accessible")
        let save = app.buttons["nextstep.saveVault"]
        XCTAssertTrue(save.exists, "Save to vault button should exist")
        save.tap()

        let vault = app.buttons["start.vault"].firstMatch
        XCTAssertTrue(vault.waitForExistence(timeout: 10), "Vault entry should exist")
        vault.tap()
        XCTAssertTrue(app.buttons["vault.item"].waitForExistence(timeout: 10), "Saved vault item should be reusable")
    }

    func testSavedStartsEmptyStateExplainsHowToSave() throws {
        let app = launch()
        openMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.reuse", childID: "start.vault")

        let savedStarts = app.buttons["start.vault"].firstMatch
        XCTAssertTrue(savedStarts.waitForExistence(timeout: 10), "Saved starts entry should exist")
        XCTAssertEqual(savedStarts.label, "Saved starts")
        savedStarts.tap()

        XCTAssertTrue(app.navigationBars["Saved starts"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No saved starts yet"].exists)
        XCTAssertTrue(
            app.staticTexts["When StartKind gives you a useful next step, open More actions and tap Save this start. It will appear here for one-tap reuse."].exists,
            "The empty state should identify the source, command, and result"
        )
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

}
