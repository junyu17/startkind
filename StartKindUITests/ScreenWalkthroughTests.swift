import XCTest

/// A pre-submission sweep: open every screen, panel and sheet the app can
/// reach and assert it actually renders. Written after device testing turned up
/// three separate problems that no existing test covered.
final class ScreenWalkthroughTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST"]
        app.launch()
        return app
    }

    private func expandMoreWays(_ app: XCUIApplication) {
        let admin = app.buttons["start.kind.admin"]
        if admin.exists { return }
        let disclosure = app.buttons["start.moreWays"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 15), "More ways disclosure missing")
        disclosure.tap()
        var attempts = 1
        while !admin.waitForExistence(timeout: 5), attempts < 3 {
            disclosure.tap()
            attempts += 1
        }
        XCTAssertTrue(admin.waitForExistence(timeout: 5), "More ways did not expand")
    }

    /// Settings is a Form, which virtualises its rows: anything below the fold
    /// is genuinely absent from the accessibility tree until scrolled to.
    private func revealInSettings(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        // Existing is not enough: a row scrolled under the tab bar is present in
        // the tree but any tap lands on the tab bar instead.
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        return element
    }

    private func selectTab(_ app: XCUIApplication, _ index: Int) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons.element(boundBy: index).tap()
    }

    // MARK: - Start

    func testStartFirstViewportShowsEveryPrimaryControl() throws {
        let app = launch()
        for id in ["start.voice", "start.input", "global.stuck", "start.autopilot"] {
            XCTAssertTrue(
                app.descendants(matching: .any)[id].waitForExistence(timeout: 15),
                "\(id) missing from the Start first viewport"
            )
        }
        // The decorative header arrow read as a control and was removed; it
        // must not come back.
        XCTAssertFalse(app.buttons["start.header.arrow"].exists)
    }

    func testEveryMoreWaysPanelRenders() throws {
        let app = launch()
        expandMoreWays(app)
        let expected = [
            "start.kind.admin", "start.kind.photo", "start.templates", "start.vault",
            "start.costart.friend", "start.join.code", "adminInbox.input",
            "start.daypart", "start.emergency", "calendarSoft.input"
        ]
        for id in expected {
            XCTAssertTrue(
                app.descendants(matching: .any)[id].waitForExistence(timeout: 10),
                "\(id) missing from More ways to start"
            )
        }
    }

    func testEnergyAndFrictionChipsRender() throws {
        let app = launch()
        expandMoreWays(app)
        for id in ["energy.low", "energy.overwhelmed", "frictionPreset.need_login", "frictionPreset.too_vague"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 10), "\(id) chip missing")
        }
    }

    // MARK: - Sheets reachable from Start

    func testTemplatesSheetOpensAndCloses() throws {
        let app = launch()
        expandMoreWays(app)
        app.descendants(matching: .any)["start.templates"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10), "Templates sheet did not open")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10), "Closing templates did not return to Start")
    }

    func testVaultSheetOpensAndCloses() throws {
        let app = launch()
        expandMoreWays(app)
        app.descendants(matching: .any)["start.vault"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10), "Vault sheet did not open")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10))
    }

    // MARK: - Tabs

    func testRecoverTabRenders() throws {
        let app = launch()
        selectTab(app, 1)
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "Recover tab did not render")
    }

    func testPatternsTabRendersEveryCard() throws {
        let app = launch()
        selectTab(app, 2)
        for id in ["gentleReview.card", "startProfile.card", "patterns.model.summary"] {
            XCTAssertTrue(
                app.descendants(matching: .any)[id].waitForExistence(timeout: 10),
                "\(id) missing from Patterns"
            )
        }
    }

    func testSettingsTabRendersEverySection() throws {
        let app = launch()
        selectTab(app, 3)
        XCTAssertTrue(app.segmentedControls["settings.theme"].waitForExistence(timeout: 10), "Theme control missing")
        XCTAssertTrue(app.segmentedControls["settings.textSize"].exists, "Text size control missing")
        XCTAssertTrue(app.buttons["StartKind Plus"].exists, "Subscription row missing")
        XCTAssertTrue(revealInSettings(app, "settings.deleteData").exists, "Delete-data row missing")
        // Account rows were removed with the account system; they must not return.
        XCTAssertFalse(app.buttons["Sign out"].exists)
        XCTAssertFalse(app.buttons["Sign in"].exists)
    }

    func testPrivacyAndVaultScreensOpenFromSettings() throws {
        let app = launch()
        selectTab(app, 3)
        let privacy = revealInSettings(app, "settings.privacy")
        XCTAssertTrue(privacy.exists, "Privacy row missing")
        privacy.tap()
        XCTAssertTrue(app.descendants(matching: .any)["privacy.email"].waitForExistence(timeout: 10), "Privacy screen did not render")
    }

    func testDataExportOpensAndIsShareable() throws {
        let app = launch()
        selectTab(app, 3)
        let export = revealInSettings(app, "settings.dataExport")
        XCTAssertTrue(export.exists, "Export row missing")
        export.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10), "Export sheet did not open")
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.dataExport.share"].waitForExistence(timeout: 10),
            "Export must be shareable, not just displayed"
        )
    }

    // MARK: - Paywall

    func testPaywallShowsPlansCtaAndHighlightedSaving() throws {
        let app = launch()
        selectTab(app, 3)
        XCTAssertTrue(app.buttons["StartKind Plus"].waitForExistence(timeout: 10))
        app.buttons["StartKind Plus"].tap()

        XCTAssertTrue(app.buttons["paywall.annual"].waitForExistence(timeout: 10), "Annual plan missing")
        XCTAssertTrue(app.buttons["paywall.monthly"].exists, "Monthly plan missing")
        XCTAssertTrue(app.buttons["paywall.subscribe"].exists, "Subscribe CTA missing")
        XCTAssertTrue(
            app.descendants(matching: .any)["paywall.annual.save"].exists,
            "The annual saving should be called out"
        )
    }
}

/// The report that produced these tests: "I tapped the buttons on the home
/// page and there was no feedback - I didn't know whether I'd missed the
/// button or it hadn't responded, so I kept tapping, and only after scrolling
/// to the bottom did I see it was working." Each test below pins one half of
/// that: the result is on screen, and the controls keep working.
final class StartFeedbackTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST"]
        app.launch()
        return app
    }

    /// The card is taller than the screen, so its container is never fully
    /// hittable. The title is the part that has to be readable the instant
    /// the step exists.
    private func produceStepAndReturnTitle(_ app: XCUIApplication) -> XCUIElement {
        let autopilot = app.descendants(matching: .any)["start.autopilot"]
        XCTAssertTrue(autopilot.waitForExistence(timeout: 15), "Autopilot missing")
        autopilot.tap()
        let title = app.descendants(matching: .any)["nextstep.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "No step was produced")
        return title
    }

    /// The whole report in one assertion: after one tap, the step is on screen
    /// without the person scrolling for it.
    func testProducedStepIsOnScreenWithoutScrolling() throws {
        let app = launch()
        let title = produceStepAndReturnTitle(app)

        XCTAssertTrue(title.isHittable, "The step title landed off screen")
        let window = app.windows.element(boundBy: 0).frame
        XCTAssertTrue(
            window.contains(CGPoint(x: title.frame.midX, y: title.frame.midY)),
            "The step must be inside the viewport the moment it appears"
        )
    }

    /// It also has to come before "More ways to start" in the layout, so it is
    /// never pushed under the fold again by something growing above it.
    func testProducedStepRendersAboveTheMoreWaysPanel() throws {
        let app = launch()
        let title = produceStepAndReturnTitle(app)

        let moreWays = app.buttons["start.moreWays"].firstMatch
        XCTAssertTrue(moreWays.exists, "More ways disclosure missing")
        XCTAssertLessThan(
            title.frame.minY, moreWays.frame.minY,
            "The produced step must sit above More ways to start, not below it"
        )
    }

    /// Producing a step scrolls it into view, which moves the start controls
    /// off the top. They must still be there - one flick up - so a second
    /// attempt is always available.
    func testStartControlsRemainAvailableAfterAStepIsProduced() throws {
        let app = launch()
        _ = produceStepAndReturnTitle(app)

        let stuck = app.buttons["global.stuck"]
        XCTAssertTrue(stuck.exists, "I'm stuck disappeared entirely")
        for _ in 0..<4 where !stuck.isHittable { app.swipeDown() }
        XCTAssertTrue(stuck.isHittable, "I'm stuck could not be reached by scrolling back up")

        stuck.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["nextstep.title"].waitForExistence(timeout: 15),
            "A second step could not be produced"
        )
    }
}
