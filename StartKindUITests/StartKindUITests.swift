import XCTest

/// UI smoke tests for the core execution loop, per `docs/TESTING_AND_DELIVERY.md`.
@MainActor
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
        let done = app.buttons["keyboard.done"].exists ? app.buttons["keyboard.done"] : app.buttons["admin.keyboard.done"]
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

    private func openMoreWays(_ app: XCUIApplication) {
        let adminButton = app.buttons["start.kind.admin"]
        if adminButton.exists { return }
        let disclosure = app.buttons["start.moreWays"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 15), "More ways section should be present")
        // The early return above already proved it is collapsed, so tap once up
        // front. After that, re-check before every further tap so a slow
        // expansion is never toggled shut again.
        disclosure.tap()
        var attempts = 1
        while !adminButton.waitForExistence(timeout: 5), attempts < 3 {
            disclosure.tap()
            attempts += 1
        }
        XCTAssertTrue(adminButton.waitForExistence(timeout: 5), "More ways section should expand")
        if !adminButton.isHittable, app.scrollViews.firstMatch.exists {
            app.scrollViews.firstMatch.swipeUp()
        }
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

    private func openSettings() -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["StartKind Plus"].waitForExistence(timeout: 10))
        app.buttons["StartKind Plus"].tap()
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

    func testVoiceTapDoesNotTerminateApp() throws {
        let app = launch()
        let voice = app.buttons["start.voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 15), "Voice button should exist")
        voice.tap()
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Voice tap should not crash or terminate the app")
    }

    func testFriendCoStartEntryVisibleAfterInput() throws {
        let app = launch()
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        openMoreWays(app)
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
        let billsChip = app.buttons["Bills"]
        XCTAssertTrue(billsChip.waitForExistence(timeout: 15), "Bills chip should exist")
        billsChip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["start.category.selected"].waitForExistence(timeout: 5), "Category selection should show visible feedback")
    }

    func testFrictionForecastCreatesStartableStep() throws {
        let app = launch()
        openMoreWays(app)
        let input = app.textFields["start.input"].exists
            ? app.textFields["start.input"]
            : app.textViews["start.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Capture field should exist")
        input.tap()
        input.typeText("I need the password before I can pay this bill")
        dismissKeyboard(app)

        let forecast = app.buttons["frictionForecast.apply"]
        XCTAssertTrue(forecast.waitForExistence(timeout: 10), "Friction Forecast should appear for a likely blocker")
        forecast.tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Friction Forecast should create a startable step")
    }

    func testKindStartAdminReaderParsesBillText() throws {
        let app = launch()
        openMoreWays(app)
        let adminButton = app.descendants(matching: .any)["start.kind.admin"]
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
        XCTAssertTrue(app.buttons["admin.startTimer"].exists, "Admin Reader should produce a startable timer step")
    }

    func testPhotoToStepAndExecutionModelEntriesVisible() throws {
        let app = launch()
        openMoreWays(app)
        XCTAssertTrue(app.descendants(matching: .any)["start.kindStart"].waitForExistence(timeout: 15), "Kind Start panel should exist")
        XCTAssertTrue(app.descendants(matching: .any)["start.kind.photo"].exists, "Photo-to-step entry should exist")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["patterns.model.summary"].waitForExistence(timeout: 10), "Personal Execution Model should be visible")
        XCTAssertTrue(app.descendants(matching: .any)["startProfile.card"].exists, "Start Profile should be visible")
    }

    func testPhotoEntryOpensDismissibleScanChoices() throws {
        let app = launch()
        openMoreWays(app)
        let photoEntry = app.descendants(matching: .any)["start.kind.photo"]
        XCTAssertTrue(photoEntry.waitForExistence(timeout: 15), "Photo entry should exist")
        photoEntry.tap()

        XCTAssertTrue(app.buttons["admin.camera"].waitForExistence(timeout: 10), "Camera scan choice should be visible")
        XCTAssertTrue(app.buttons["admin.photoLibrary"].exists, "Photo library scan choice should be visible")
        XCTAssertTrue(app.buttons["admin.photo"].exists, "Inline photo choice should remain available")

        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Admin scan screen should be dismissible")
        close.tap()
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10), "Closing scan screen should return to Start")
    }

    func testAutopilotCreatesOneNextStep() throws {
        let app = launch()
        let autopilot = app.descendants(matching: .any)["start.autopilot"]
        XCTAssertTrue(autopilot.waitForExistence(timeout: 15), "Autopilot entry should exist")
        autopilot.tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Autopilot should create a startable next step")
    }

    func testStartLadderAndUrgentAdminEntriesWork() throws {
        let app = launch()
        openMoreWays(app)
        let autopilot = app.descendants(matching: .any)["start.autopilot"]
        XCTAssertTrue(autopilot.waitForExistence(timeout: 15))
        autopilot.tap()
        XCTAssertTrue(app.buttons["nextstep.ladder.2"].waitForExistence(timeout: 10), "Start Ladder should offer a two-minute version")
        app.buttons["nextstep.ladder.2"].tap()
        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Selected ladder version should remain startable")

        let admin = app.descendants(matching: .any)["start.kind.admin"]
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
        XCTAssertTrue(app.textFields["adminInbox.input"].waitForExistence(timeout: 15), "Tiny admin inbox should be visible")

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
        let subscribe = app.buttons["paywall.subscribe"]
        XCTAssertTrue(comparison.waitForExistence(timeout: 10), "Paywall should compare Free and Plus")
        XCTAssertTrue(annual.waitForExistence(timeout: 10), "Annual selector should exist")
        XCTAssertTrue(monthly.waitForExistence(timeout: 10), "Monthly selector should exist")
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10), "Subscribe button should exist")
        XCTAssertLessThan(annual.frame.minY, comparison.frame.minY, "Annual selector should precede Free-vs-Plus comparison")
        XCTAssertLessThan(monthly.frame.minY, comparison.frame.minY, "Monthly selector should precede Free-vs-Plus comparison")
        XCTAssertLessThan(subscribe.frame.minY, comparison.frame.minY, "Subscribe CTA should precede Free-vs-Plus comparison")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "9.99")).count > 0, "Fallback monthly price should be visible")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "89.99")).count > 0, "Fallback annual price should be visible")

        monthly.tap()
        XCTAssertTrue(subscribe.waitForExistence(timeout: 5), "Subscribe button should still exist after plan select")
    }

    func testMoreWaysRevealsSecondaryOptions() throws {
        let app = launch()
        openMoreWays(app)
        XCTAssertTrue(app.buttons["start.kind.admin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start.kind.photo"].exists, "Photo scan should be in more ways")
        XCTAssertTrue(app.buttons["start.templates"].exists, "Templates should be in more ways")
        XCTAssertTrue(app.buttons["start.vault"].exists, "Vault should be in more ways")
        XCTAssertTrue(app.textFields["adminInbox.input"].exists, "Tiny admin inbox should be in more ways")
        XCTAssertTrue(app.buttons["start.costart.friend"].exists, "Friend co-start should be in more ways")
        XCTAssertTrue(app.buttons["start.join.submit"].exists, "Room code join should be in more ways")
        XCTAssertTrue(app.buttons["energy.overwhelmed"].exists, "Energy panels should be in more ways")
        XCTAssertTrue(app.buttons["frictionPreset.too_many_tabs"].exists, "Friction presets should be in more ways")
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
        let templates = app.descendants(matching: .any)["start.templates"]
        XCTAssertTrue(templates.waitForExistence(timeout: 15), "Templates entry should exist")
        templates.tap()

        let billTemplate = app.buttons["template.bill_anchor"]
        XCTAssertTrue(billTemplate.waitForExistence(timeout: 10), "Bill template should exist")
        billTemplate.tap()

        XCTAssertTrue(app.buttons["nextstep.start"].waitForExistence(timeout: 10), "Template should create a local next step")
        XCTAssertTrue(app.buttons["nextstep.share"].exists, "Start card share button should exist")
        let save = app.buttons["nextstep.saveVault"]
        XCTAssertTrue(save.exists, "Save to vault button should exist")
        save.tap()

        let vault = app.descendants(matching: .any)["start.vault"]
        XCTAssertTrue(vault.waitForExistence(timeout: 10), "Vault entry should exist")
        vault.tap()
        XCTAssertTrue(app.buttons["vault.item"].waitForExistence(timeout: 10), "Saved vault item should be reusable")
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
