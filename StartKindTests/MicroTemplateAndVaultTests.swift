import XCTest
@testable import StartKind

@MainActor
final class MicroTemplateAndVaultTests: XCTestCase {
    func testTemplatesProduceLocalStartableSteps() {
        let templates = MicroTemplateLibrary.templates(language: "en")
        XCTAssertGreaterThanOrEqual(templates.count, 6)
        for template in templates {
            XCTAssertFalse(template.id.isEmpty)
            XCTAssertFalse(template.proposal.title.isEmpty)
            XCTAssertFalse(template.proposal.step.isEmpty)
            XCTAssertTrue((3...7).contains(template.proposal.timerMinutes))
            XCTAssertNotEqual(template.proposal.generatedBy, .cloudAI)
        }
    }

    func testVaultPersistsAndDeduplicatesItems() {
        let suite = "vault-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let vault = PersonalVaultStore(defaults: defaults)
        vault.add(title: "Find bill", body: "Open one email", category: .bills)
        vault.add(title: "Find bill", body: "Open one email", category: .bills)

        XCTAssertEqual(vault.items.count, 1)
        XCTAssertEqual(vault.items.first?.category, .bills)

        let reloaded = PersonalVaultStore(defaults: defaults)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.body, "Open one email")
    }

    func testCaptureDeepLinkStoresPendingText() {
        let env = AppEnvironment(inMemory: true)
        env.handleJoinURL(URL(string: "startkind://capture?text=Pay%20the%20bill")!)
        XCTAssertEqual(env.pendingCaptureText, "Pay the bill")
    }

    func testRescueDeepLinkArmsAutopilotRestart() {
        let env = AppEnvironment(inMemory: true)
        env.handleJoinURL(URL(string: "startkind://rescue")!)
        XCTAssertTrue(env.pendingRescueRestart)
    }

    func testAutopilotPrefersActiveRecoveryCapsule() throws {
        let svc = try PersistenceService(inMemory: true)
        let step = svc.saveNextStep(proposal: NextStepProposal(title: "Resume bill", step: "Open the bill email", timerMinutes: 10, stopCondition: "Stop at the due date", category: .bills), capture: nil, taskTitle: "Resume bill")
        svc.upsertRecoveryCapsule(for: step, isPlus: false, blocker: .tooBig, returnNote: "Email is open")

        let proposal = AutopilotPlanner().proposal(
            capsule: svc.activeRecoveryCapsule(),
            vaultItems: [],
            templates: MicroTemplateLibrary.templates(language: "en"),
            currentHour: 14
        )

        XCTAssertEqual(proposal.title, "Resume bill")
        XCTAssertEqual(proposal.category, .bills)
        XCTAssertEqual(proposal.whyThisStep, "Your return note says: Email is open")
    }

    func testAutopilotUsesVaultBeforeTemplates() {
        let vaultItem = VaultItem(title: "Saved start", body: "Open one tab", category: .workAdmin)
        let proposal = AutopilotPlanner().proposal(
            capsule: nil,
            vaultItems: [vaultItem],
            templates: MicroTemplateLibrary.templates(language: "en"),
            currentHour: 14
        )

        XCTAssertEqual(proposal.title, "Saved start")
        XCTAssertEqual(proposal.step, "Open one tab")
        XCTAssertEqual(proposal.category, .workAdmin)
    }

    func testFrictionMapReportsCommonBlocker() throws {
        let svc = try PersistenceService(inMemory: true)
        let step1 = svc.saveNextStep(proposal: NextStepProposal(title: "Bill", step: "Open bill", timerMinutes: 5, stopCondition: "Stop", category: .bills), capture: nil, taskTitle: "Bill")
        let step2 = svc.saveNextStep(proposal: NextStepProposal(title: "Email", step: "Open email", timerMinutes: 5, stopCondition: "Stop", category: .email), capture: nil, taskTitle: "Email")
        svc.upsertRecoveryCapsule(for: step1, isPlus: true, blocker: .needLogin)
        svc.upsertRecoveryCapsule(for: step2, isPlus: true, blocker: .needLogin)

        let insights = FrictionMap().insights(capsules: svc.recoveryCapsules(), snapshots: [])

        XCTAssertEqual(insights.first?.blocker, .needLogin)
        XCTAssertEqual(insights.first?.suggestedStep, "Find the login page and stop before entering details.")
    }
}
