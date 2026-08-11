import XCTest
@testable import StartKind

@MainActor
final class RetentionFeatureTests: XCTestCase {
    func testEnergyMatcherOverwhelmedShrinksToFrictionOnly() {
        let base = NextStepProposal(title: "Pay bill", step: "Open bill", timerMinutes: 12, stopCondition: "Stop", category: .bills)
        let matched = EnergyMatcher().apply(base, energy: .overwhelmed, language: "en")
        XCTAssertEqual(matched.timerMinutes, 5)
        XCTAssertEqual(matched.shrinkLevel, .three)
        XCTAssertTrue(matched.step.lowercased().contains("exhale"))
    }

    func testFrictionPresetTooManyTabsCreatesTinyStep() {
        let proposal = FrictionPresetPlanner().proposal(for: .tooManyTabs, category: .workAdmin, language: "en")
        XCTAssertEqual(proposal.category, .workAdmin)
        XCTAssertEqual(proposal.timerMinutes, 5)
        XCTAssertEqual(proposal.shrinkLevel, .three)
        XCTAssertTrue(proposal.step.lowercased().contains("tab"))
    }

    func testProofOfStartPersistsAndCountsRecentStarts() {
        let suite = "proof-start-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProofOfStartStore(defaults: defaults)
        let stepId = UUID()
        store.record(stepId: stepId, title: "Open bill", category: .bills)
        store.record(stepId: stepId, title: "Open bill again", category: .bills)
        XCTAssertEqual(store.recentCount(), 1)
        let reloaded = ProofOfStartStore(defaults: defaults)
        XCTAssertEqual(reloaded.events.first?.title, "Open bill")
    }

    func testTinyAdminInboxStoresOnlyOneProposalCard() {
        let suite = "admin-inbox-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TinyAdminInboxStore(defaults: defaults)
        let proposal = NextStepProposal(title: "Find due date", step: "Open the bill", timerMinutes: 5, stopCondition: "Stop", category: .bills)
        store.add(rawText: String(repeating: "bill ", count: 600), proposal: proposal)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.proposal.title, "Find due date")
        XCTAssertLessThanOrEqual(store.items.first?.rawText.count ?? 0, 2_000)
    }

    func testYesterdayRescuePrefersActiveCapsule() throws {
        let svc = try PersistenceService(inMemory: true)
        let step = svc.saveNextStep(proposal: NextStepProposal(title: "Resume", step: "Open email", timerMinutes: 10, stopCondition: "Stop", category: .email), capture: nil, taskTitle: "Resume")
        svc.upsertRecoveryCapsule(for: step, isPlus: false, blocker: .tooBig)
        let rescue = YesterdayRescuePlanner().proposal(activeCapsule: svc.activeRecoveryCapsule(), recentSteps: [], language: "en")
        XCTAssertEqual(rescue?.timerMinutes, 3)
        XCTAssertEqual(rescue?.category, .email)
        XCTAssertTrue(rescue?.whyThisStep?.lowercased().contains("gentle") == true)
    }

    func testAppEnvironmentCreatesStuckStep() {
        let env = AppEnvironment(inMemory: true)
        let step = env.createStuckStep(current: nil)
        XCTAssertEqual(step.shrinkLevel, .three)
        XCTAssertEqual(step.category, .other)
    }
}
