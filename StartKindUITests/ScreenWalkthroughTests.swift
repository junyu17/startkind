import XCTest

/// A pre-submission sweep: open every screen, panel and sheet the app can
/// reach and assert it actually renders. Written after device testing turned up
/// three separate problems that no existing test covered.
@MainActor
final class ScreenWalkthroughTests: XCTestCase {

    private func launch(plus: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST"]
        if plus { app.launchArguments.append("-UITEST_PLUS") }
        app.launch()
        return app
    }

    private func scrollToHittable(_ app: XCUIApplication, _ element: XCUIElement, label: String) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(label) should be hittable")
    }

    private func expandMoreWays(_ app: XCUIApplication) {
        let scanGroup = app.buttons["start.moreWays.scan"].firstMatch
        if scanGroup.exists { return }
        let disclosure = app.buttons["start.moreWays"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 15), "More ways disclosure missing")
        scrollToHittable(app, disclosure, label: "More ways disclosure")
        disclosure.tap()
        XCTAssertTrue(scanGroup.waitForExistence(timeout: 5), "More ways did not expand")
    }

    private func expandMoreWaysGroup(_ app: XCUIApplication, _ groupID: String, childID: String) {
        let group = app.buttons[groupID].firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 10), "More ways group \(groupID) missing")
        let child = app.descendants(matching: .any)[childID]
        if !child.exists {
            scrollToHittable(app, group, label: "More ways group \(groupID)")
            group.tap()
        }
        XCTAssertTrue(child.waitForExistence(timeout: 10), "\(childID) missing after expanding \(groupID)")
        scrollToHittable(app, child, label: "More ways child \(childID)")
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
        for id in ["start.voice", "start.input", "global.stuck", "start.moreWays"] {
            XCTAssertTrue(
                app.descendants(matching: .any)[id].waitForExistence(timeout: 15),
                "\(id) missing from the Start first viewport"
            )
        }
        XCTAssertTrue(app.staticTexts["One kind step to start."].waitForExistence(timeout: 10), "Start guidance should remain visible as text")
        XCTAssertFalse(app.buttons["One kind step to start."].exists, "Start guidance must not be exposed as a control")
        XCTAssertFalse(app.descendants(matching: .any)["start.autopilot"].exists, "Autopilot belongs in More ways")
        XCTAssertFalse(app.descendants(matching: .any)["start.yesterdayRescue"].exists, "Yesterday Rescue belongs in More ways")
        // The decorative header arrow read as a control and was removed; it
        // must not come back.
        XCTAssertFalse(app.buttons["start.header.arrow"].exists)
    }

    func testEveryMoreWaysPanelRenders() throws {
        let app = launch()
        expandMoreWays(app)
        for id in ["start.moreWays.scan", "start.moreWays.reuse", "start.moreWays.costart", "start.moreWays.match", "start.moreWays.plan"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 10), "\(id) group missing")
        }
        XCTAssertFalse(app.descendants(matching: .any)["start.kind.admin"].exists, "Admin tools should not be eager")
        XCTAssertFalse(app.descendants(matching: .any)["start.join.code"].exists, "Co-start tools should not be eager")
        XCTAssertFalse(app.descendants(matching: .any)["start.costart.quiet"].exists, "Quiet co-start should not be eager")
        XCTAssertFalse(app.descendants(matching: .any)["energy.low"].exists, "Match tools should not be eager")
        XCTAssertFalse(app.descendants(matching: .any)["calendarSoft.input"].exists, "Plan tools should not be eager")

        expandMoreWaysGroup(app, "start.moreWays.scan", childID: "start.kind.admin")
        for id in ["start.kind.photo", "adminInbox.input"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 10), "\(id) missing from Scan or paste")
        }
        XCTAssertFalse(app.buttons["start.templates"].exists, "Templates should not be in Scan or paste")
        XCTAssertFalse(app.buttons["start.vault"].exists, "Saved starts should not be in Scan or paste")
        expandMoreWaysGroup(app, "start.moreWays.reuse", childID: "start.templates")
        XCTAssertTrue(app.buttons["start.vault"].waitForExistence(timeout: 10), "Saved starts missing from Reuse a start")
        XCTAssertTrue(app.descendants(matching: .any)["startScript.title"].waitForExistence(timeout: 10), "Reusable scripts missing from Reuse a start")
        expandMoreWaysGroup(app, "start.moreWays.costart", childID: "start.costart.friend")
        XCTAssertTrue(app.buttons["start.costart.quiet"].waitForExistence(timeout: 10), "Quiet co-start missing from Start with someone")
        XCTAssertTrue(app.descendants(matching: .any)["start.join.code"].waitForExistence(timeout: 10))
        expandMoreWaysGroup(app, "start.moreWays.match", childID: "energy.low")
        for id in ["frictionPreset.need_login", "start.daypart", "start.emergency"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 10), "\(id) missing from Match how I feel")
        }
        expandMoreWaysGroup(app, "start.moreWays.plan", childID: "start.autopilot")
        XCTAssertTrue(app.descendants(matching: .any)["calendarSoft.input"].waitForExistence(timeout: 10))
    }

    func testEnergyAndFrictionChipsRender() throws {
        let app = launch()
        expandMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.match", childID: "energy.low")
        for id in ["energy.low", "energy.overwhelmed", "frictionPreset.need_login", "frictionPreset.too_vague"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 10), "\(id) chip missing")
        }
    }

    // MARK: - Sheets reachable from Start

    func testTemplatesSheetOpensAndCloses() throws {
        let app = launch()
        expandMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.reuse", childID: "start.templates")
        app.buttons["start.templates"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10), "Templates sheet did not open")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["start.voice"].waitForExistence(timeout: 10), "Closing templates did not return to Start")
    }

    func testVaultSheetOpensAndCloses() throws {
        let app = launch()
        expandMoreWays(app)
        expandMoreWaysGroup(app, "start.moreWays.reuse", childID: "start.vault")
        app.buttons["start.vault"].firstMatch.tap()
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
        let app = launch(plus: true)
        selectTab(app, 2)
        for id in ["patterns.recommendation", "gentleReview.card", "startProfile.card", "patterns.advanced"] {
            XCTAssertTrue(
                app.descendants(matching: .any)[id].waitForExistence(timeout: 10),
                "\(id) missing from Patterns"
            )
        }
        XCTAssertFalse(app.descendants(matching: .any)["patterns.model.summary"].exists, "Plus details should start collapsed")
        let advanced = app.buttons["patterns.advanced"].firstMatch
        for _ in 0..<8 where !advanced.isHittable { app.swipeUp() }
        XCTAssertTrue(advanced.isHittable, "Plus details disclosure should be tappable")
        advanced.tap()
        XCTAssertTrue(app.descendants(matching: .any)["patterns.model.summary"].waitForExistence(timeout: 10))
    }

    func testSettingsTabRendersEverySection() throws {
        let app = launch()
        selectTab(app, 3)
        XCTAssertTrue(app.segmentedControls["settings.theme"].waitForExistence(timeout: 10), "Theme control missing")
        let textSize = app.descendants(matching: .any)["settings.textSize"]
        XCTAssertTrue(textSize.waitForExistence(timeout: 10), "Text size control missing")
        textSize.tap()
        XCTAssertTrue(app.buttons["Smaller"].waitForExistence(timeout: 5), "Text size menu should expose the smaller levels")
        app.buttons["Standard"].tap()
        XCTAssertTrue(app.buttons["settings.subscription.upgrade"].exists, "Free upgrade action missing")
        XCTAssertTrue(app.descendants(matching: .any)["settings.subscription.status"].exists, "Subscription status missing")
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
        XCTAssertTrue(app.descendants(matching: .any)["privacy.policy"].waitForExistence(timeout: 10), "Full privacy policy link missing")
        XCTAssertTrue(app.descendants(matching: .any)["privacy.terms"].exists, "Terms link missing")
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

    func testPaywallShowsProductErrorRetryAndLegalLinks() throws {
        let app = launch()
        selectTab(app, 3)
        let upgrade = revealInSettings(app, "settings.subscription.upgrade")
        XCTAssertTrue(upgrade.exists && upgrade.isHittable, "Free upgrade action missing")
        upgrade.tap()

        XCTAssertTrue(app.buttons["paywall.annual"].waitForExistence(timeout: 10), "Annual plan missing")
        XCTAssertTrue(app.buttons["paywall.monthly"].exists, "Monthly plan missing")
        let retry = app.buttons["paywall.products.retry"]
        let subscribe = app.buttons["paywall.subscribe"]
        if retry.exists {
            XCTAssertFalse(app.buttons["paywall.annual"].isEnabled, "Unavailable annual plan must be disabled")
            XCTAssertFalse(app.buttons["paywall.monthly"].isEnabled, "Unavailable monthly plan must be disabled")
            XCTAssertFalse(subscribe.exists, "A failed product load must not leave a dead subscribe CTA")
        } else {
            XCTAssertTrue(subscribe.waitForExistence(timeout: 10), "Loaded products must expose the subscribe action")
            XCTAssertTrue(app.buttons["paywall.annual"].isEnabled)
            XCTAssertTrue(app.buttons["paywall.monthly"].isEnabled)
        }
        XCTAssertTrue(app.buttons["paywall.privacy"].exists, "Privacy link missing")
        XCTAssertTrue(app.buttons["paywall.terms"].exists, "Terms link missing")
    }

    func testPlusSettingsShowsManageSubscriptionWithoutUpgrade() throws {
        let app = launch(plus: true)
        selectTab(app, 3)

        let manage = revealInSettings(app, "settings.subscription.manage")
        XCTAssertTrue(manage.exists && manage.isHittable, "Plus manage action missing")
        XCTAssertTrue(app.descendants(matching: .any)["settings.subscription.status"].exists)
        let restore = revealInSettings(app, "settings.subscription.restore")
        XCTAssertTrue(restore.exists, "Plus restore action missing")
        XCTAssertFalse(app.buttons["settings.subscription.upgrade"].exists, "Plus must not show the upgrade action")
    }
}

@MainActor
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

    private func scrollToHittable(_ app: XCUIApplication, _ element: XCUIElement, label: String) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(label) should be hittable")
    }

    /// The card is taller than the screen, so its container is never fully
    /// hittable. The title is the part that has to be readable the instant
    /// the step exists.
    private func produceStepAndReturnTitle(_ app: XCUIApplication) -> XCUIElement {
        let autopilot = app.buttons["start.autopilot"].firstMatch
        let moreWays = app.buttons["start.moreWays"].firstMatch
        XCTAssertTrue(moreWays.waitForExistence(timeout: 15), "More ways disclosure missing")
        scrollToHittable(app, moreWays, label: "More ways disclosure")
        moreWays.tap()
        let plan = app.buttons["start.moreWays.plan"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10), "Plan group missing")
        scrollToHittable(app, plan, label: "Plan group")
        plan.tap()
        XCTAssertTrue(autopilot.waitForExistence(timeout: 15), "Autopilot missing")
        scrollToHittable(app, autopilot, label: "Autopilot")
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
