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
        XCTAssertTrue(env.hasStarted)
    }
}
