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

    func testStuckCompletionReopensSameTaskAtNextLargerRung() {
        let env = AppEnvironment(inMemory: true)
        let root = NextStepProposal(
            title: "Find the bill",
            step: "Open the bill email.",
            timerMinutes: 12,
            stopCondition: "Stop when it is open.",
            category: .bills
        )
        let step = env.createLocalNextStep(proposal: root, sourceText: "bill")
        let originalStepID = step.id
        let originalTaskID = step.taskId

        XCTAssertEqual(env.createStuckStep(current: step).shrinkLevel, .one)
        XCTAssertEqual(env.createStuckStep(current: step).shrinkLevel, .two)
        XCTAssertEqual(env.createStuckStep(current: step).shrinkLevel, .three)
        XCTAssertEqual(step.id, originalStepID)
        XCTAssertEqual(step.taskId, originalTaskID)

        let session = env.startTimer(step: step, minutes: step.targetMinutes)
        env.finishTimer(session: session, actualSeconds: 30, outcome: .completed, step: step)
        XCTAssertEqual(step.status, .completed)

        let next = env.reopenNextLargerStep(step, rootProposal: root)
        XCTAssertEqual(next?.shrinkLevel, .two)
        XCTAssertEqual(step.shrinkLevel, .two)
        XCTAssertEqual(step.status, .suggested)
        XCTAssertNil(step.completedAt)
        XCTAssertEqual(step.id, originalStepID)
        XCTAssertEqual(step.taskId, originalTaskID)
    }

    func testCompletedShrinkRungsProgressBackToRootBeforeTaskFinishes() {
        let env = AppEnvironment(inMemory: true)
        let root = NextStepProposal(
            title: "Open the message",
            step: "Open the message and read it.",
            timerMinutes: 10,
            stopCondition: "Stop after reading it.",
            category: .email
        )
        let step = env.createLocalNextStep(proposal: root, sourceText: "message")
        _ = env.createStuckStep(current: step)
        _ = env.createStuckStep(current: step)
        _ = env.createStuckStep(current: step)

        XCTAssertEqual(env.reopenNextLargerStep(step, rootProposal: root)?.shrinkLevel, .two)
        XCTAssertEqual(env.reopenNextLargerStep(step, rootProposal: root)?.shrinkLevel, .one)
        XCTAssertEqual(env.reopenNextLargerStep(step, rootProposal: root)?.shrinkLevel, .zero)
        XCTAssertNil(env.reopenNextLargerStep(step, rootProposal: root))
        XCTAssertEqual(step.proposal.title, root.title)
        XCTAssertEqual(step.proposal.step, root.step)
    }

    func testGenerateNextStepReturnsImmediatelyWhileCloudIsSlow() async throws {
        let env = makeEnvironment(
            ai: DelayedNextStepAIClient(delay: .milliseconds(800), proposal: cloudProposal())
        )
        let clock = ContinuousClock()
        let startedAt = clock.now

        let step = try await env.generateNextStep(input: captureInput())

        XCTAssertTrue(startedAt.duration(to: clock.now) < .milliseconds(300))
        XCTAssertEqual(step.generatedBy, .localTemplate)
        XCTAssertFalse(step.stepText.isEmpty)
    }

    func testFastCloudRefinementKeepsTheSameStepIdentity() async throws {
        let env = makeEnvironment(
            ai: DelayedNextStepAIClient(delay: .milliseconds(30), proposal: cloudProposal())
        )
        let step = try await env.generateNextStep(input: captureInput())
        let stepID = step.id
        let taskID = step.taskId

        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(step.id, stepID)
        XCTAssertEqual(step.taskId, taskID)
        XCTAssertEqual(step.title, "Check the fan power")
        XCTAssertEqual(step.generatedBy, .cloudAI)
    }

    func testLateCloudRefinementDoesNotReplaceLocalStep() async throws {
        let env = makeEnvironment(
            ai: DelayedNextStepAIClient(delay: .milliseconds(1_100), proposal: cloudProposal())
        )
        let step = try await env.generateNextStep(input: captureInput())
        let localProposal = step.proposal

        try await Task.sleep(for: .milliseconds(1_200))

        XCTAssertEqual(step.proposal, localProposal)
        XCTAssertEqual(step.generatedBy, .localTemplate)
    }

    func testStartedStepIsNotReplacedByCloudRefinement() async throws {
        let env = makeEnvironment(
            ai: DelayedNextStepAIClient(delay: .milliseconds(80), proposal: cloudProposal())
        )
        let step = try await env.generateNextStep(input: captureInput())
        let localProposal = step.proposal
        _ = env.startTimer(step: step, minutes: step.targetMinutes)

        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(step.title, localProposal.title)
        XCTAssertEqual(step.generatedBy, .localTemplate)
        XCTAssertEqual(step.status, .started)
    }

    func testChangedStepIsNotReplacedByCloudRefinement() async throws {
        let env = makeEnvironment(
            ai: DelayedNextStepAIClient(delay: .milliseconds(80), proposal: cloudProposal())
        )
        let step = try await env.generateNextStep(input: captureInput())
        let changedProposal = env.shrinkCurrentStep(step)

        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(step.proposal.title, changedProposal.title)
        XCTAssertEqual(step.proposal.step, changedProposal.step)
        XCTAssertEqual(step.shrinkLevel, changedProposal.shrinkLevel)
        XCTAssertEqual(step.generatedBy, .localTemplate)
    }

    private func makeEnvironment(ai: AIClient) -> AppEnvironment {
        let suite = "instant-step-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppEnvironment(
            inMemory: true,
            usageDefaults: defaults,
            profileDefaults: defaults,
            aiClient: ai
        )
    }

    private func captureInput() -> CaptureInput {
        CaptureInput(rawText: "fix the fan", source: .text, language: "en")
    }

    private func cloudProposal() -> NextStepProposal {
        NextStepProposal(
            title: "Check the fan power",
            step: "Stand by the fan and check whether its power plug is seated.",
            timerMinutes: 5,
            stopCondition: "Stop after checking the plug.",
            category: .household,
            generatedBy: .cloudAI
        )
    }
}

private struct DelayedNextStepAIClient: AIClient {
    let delay: Duration
    let proposal: NextStepProposal

    func generateNextStep(
        input: CaptureInput,
        calibrationMultiplier: Double
    ) async throws -> NextStepProposal {
        try await Task.sleep(for: delay)
        return proposal
    }

    func parseAdmin(text: String, language: String) async throws -> AdminParseResult {
        throw DelayedNextStepAIClientError.unused
    }
}

private enum DelayedNextStepAIClientError: Error {
    case unused
}
