import XCTest
@testable import StartKind

@MainActor
final class SavedStartCompletionTests: XCTestCase {
    private func makeVault() -> (String, UserDefaults, PersonalVaultStore) {
        let suite = "saved-start-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (suite, defaults, PersonalVaultStore(defaults: defaults))
    }

    private func proposal() -> NextStepProposal {
        NextStepProposal(
            title: "Open the bill",
            step: "Find the bill email",
            timerMinutes: 5,
            stopCondition: "Stop when it is open",
            category: .bills
        )
    }

    func testCompletedRootProducesPromptDraft() {
        let (suite, defaults, vault) = makeVault()
        defer { defaults.removePersistentDomain(forName: suite) }

        let draft = SavedStartCompletionPolicy.draft(
            outcome: .completed,
            isRootFinished: true,
            proposal: proposal(),
            vault: vault
        )

        XCTAssertEqual(draft?.title, "Open the bill")
    }

    func testPausedCompletionDoesNotProducePromptDraft() {
        let (suite, defaults, vault) = makeVault()
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(SavedStartCompletionPolicy.draft(
            outcome: .paused,
            isRootFinished: true,
            proposal: proposal(),
            vault: vault
        ))
    }

    func testCompletedShrinkRungDoesNotProducePromptDraft() {
        let (suite, defaults, vault) = makeVault()
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(SavedStartCompletionPolicy.draft(
            outcome: .completed,
            isRootFinished: false,
            proposal: proposal(),
            vault: vault
        ))
    }

    func testEquivalentSavedStartSuppressesPrompt() {
        let (suite, defaults, vault) = makeVault()
        defer { defaults.removePersistentDomain(forName: suite) }

        vault.add(title: " Open the bill ", body: "FIND   THE BILL EMAIL", category: .bills)

        XCTAssertTrue(vault.containsEquivalent(title: "Open the bill", body: "Find the bill email"))
        XCTAssertNil(SavedStartCompletionPolicy.draft(
            outcome: .completed,
            isRootFinished: true,
            proposal: proposal(),
            vault: vault
        ))
    }

    func testSavingCompletedDraftPutsItemInVaultAndDeduplicates() {
        let (suite, defaults, vault) = makeVault()
        defer { defaults.removePersistentDomain(forName: suite) }

        let item = vault.add(title: proposal().title, body: proposal().step, category: proposal().category)
        vault.add(title: "  \(item.title) ", body: "\(item.body)  ", category: .bills)

        XCTAssertEqual(vault.items.count, 1)
        XCTAssertTrue(vault.containsEquivalent(title: item.title, body: item.body))
        XCTAssertEqual(vault.items.first?.title, item.title)
    }
}
