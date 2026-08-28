import XCTest
@testable import StartKind

@MainActor
final class FifthRetentionFeatureTests: XCTestCase {
    private func proposal(
        title: String = "Pay the bill",
        step: String = "Open https://example.com/pay and find the amount.",
        category: TaskCategory = .bills
    ) -> NextStepProposal {
        NextStepProposal(
            title: title,
            step: step,
            timerMinutes: 10,
            stopCondition: "Stop after the amount is visible.",
            category: category
        )
    }

    func testStartLadderCreatesSeparateBoundedVersions() {
        let original = proposal()
        let planner = StartLadderPlanner()
        XCTAssertEqual(StartLadderPlanner.minutes, [2, 5, 15])
        let two = planner.proposal(from: original, minutes: 2, language: "en")
        let fifteen = planner.proposal(from: original, minutes: 15, language: "en")
        XCTAssertEqual(two.timerMinutes, 2)
        XCTAssertEqual(fifteen.timerMinutes, 15)
        XCTAssertEqual(original.timerMinutes, 10)
        XCTAssertTrue(two.stopCondition.contains("2 minutes"))
    }

    func testActionPrepUsesOnlyUserInitiatedDestinations() {
        let planner = ActionPrepPlanner()
        let website = planner.plan(for: proposal(), language: "en")
        XCTAssertEqual(website?.kind, .website)
        XCTAssertEqual(website?.url?.host, "example.com")

        let email = planner.plan(for: proposal(step: "Email billing@example.com with one question."), language: "en")
        XCTAssertEqual(email?.kind, .email)
        XCTAssertEqual(email?.url?.scheme, "mailto")

        let phone = planner.plan(for: proposal(step: "Call 415-555-0123 and ask one question."), language: "en")
        XCTAssertEqual(phone?.kind, .phone)
        XCTAssertEqual(phone?.url?.scheme, "tel")

        let appointment = planner.plan(for: proposal(step: "Confirm the appointment time.", category: .appointments), language: "en")
        XCTAssertEqual(appointment?.kind, .appointment)
        XCTAssertNil(appointment?.url)
    }

    func testDailyOneThingPrefersRecoveryAndPersistsForTheDay() {
        let suite = "daily-one-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let planner = DailyOneThingPlanner()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let recovery = DailyOneThingCandidate(id: UUID(), proposal: proposal(title: "Resume bill"), source: .recovery)
        let admin = DailyOneThingCandidate(id: UUID(), proposal: proposal(title: "Admin bill"), source: .admin)
        let store = DailyOneThingStore(defaults: defaults)
        XCTAssertEqual(store.select(from: [admin, recovery], date: date, planner: planner)?.source, .recovery)
        XCTAssertEqual(store.item(for: date, planner: planner)?.proposal.title, "Resume bill")
        let reloaded = DailyOneThingStore(defaults: defaults)
        XCTAssertEqual(reloaded.item(for: date, planner: planner)?.candidateID, recovery.id)
        XCTAssertEqual(reloaded.replace(from: [admin, recovery], date: date, planner: planner)?.source, .admin)
        reloaded.dismiss()
        XCTAssertNil(reloaded.item(for: date, planner: planner))
    }

    func testStartProfileUsesObservedTimeWithoutAProductivityScore() {
        let samples = [
            CalibrationSample(category: .email, estimatedMinutes: 5, actualSeconds: 240, outcome: .completed, startHour: 9, coStartUsed: false),
            CalibrationSample(category: .email, estimatedMinutes: 5, actualSeconds: 300, outcome: .partial, startHour: 10, coStartUsed: false),
            CalibrationSample(category: .bills, estimatedMinutes: 10, actualSeconds: 360, outcome: .completed, startHour: 9, coStartUsed: false)
        ]
        let profile = StartProfilePlanner().profile(samples: samples)
        XCTAssertEqual(profile.sampleCount, 3)
        XCTAssertEqual(profile.preferredWindow, .morning)
        XCTAssertEqual(profile.helpfulMinutes, 5)
        XCTAssertEqual(profile.productiveCategory, .email)
    }

    func testUrgentAdminUsesNeutralContactFirstStart() {
        let signal = UrgentAdminPlanner().signal(
            in: "Final notice: payment is due today. Visit the original portal.",
            language: "en"
        )
        XCTAssertEqual(signal?.proposal.category, .bills)
        XCTAssertEqual(signal?.proposal.timerMinutes, 5)
        XCTAssertTrue(signal?.proposal.step.contains("contact") ?? false)
        XCTAssertNil(UrgentAdminPlanner().signal(in: "A regular update from the provider.", language: "en"))
    }

    func testCoStartContinuityIsLocalAndReplaceable() {
        let suite = "costart-continuity-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CoStartContinuityStore(defaults: defaults)
        store.save(displayName: "Jamie", roomCode: "123456")
        XCTAssertEqual(store.preferred?.displayName, "Jamie")
        XCTAssertEqual(store.preferred?.lastRoomCode, "123456")
        let reloaded = CoStartContinuityStore(defaults: defaults)
        XCTAssertEqual(reloaded.preferred?.displayName, "Jamie")
        reloaded.clear()
        XCTAssertNil(reloaded.preferred)
    }
}
