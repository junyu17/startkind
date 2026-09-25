import XCTest
@testable import StartKind

@MainActor
final class OnboardingProfileStoreTests: XCTestCase {
    func testProfileNormalizesAndPersists() {
        let suite = "onboarding-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OnboardingProfileStore(defaults: defaults)
        XCTAssertTrue(store.save(firstName: "  Ana\n", difficulty: .interruptions))
        XCTAssertEqual(store.firstName, "Ana")
        XCTAssertEqual(store.difficulty, .interruptions)
        XCTAssertTrue(store.isComplete)

        let reloaded = OnboardingProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.firstName, "Ana")
        XCTAssertEqual(reloaded.difficulty, .interruptions)
        XCTAssertTrue(reloaded.isComplete)
    }

    func testProfileRejectsBlankAndOverlongNames() {
        XCTAssertFalse(OnboardingProfileStore.isValidFirstName("   "))
        XCTAssertFalse(OnboardingProfileStore.isValidFirstName(String(repeating: "a", count: 41)))
        XCTAssertTrue(OnboardingProfileStore.isValidFirstName(String(repeating: "a", count: 40)))
    }

    func testProfileResetClearsLocalSetup() {
        let suite = "onboarding-reset-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = OnboardingProfileStore(defaults: defaults)
        XCTAssertTrue(store.save(firstName: "Kai", difficulty: .adminPileUp))
        store.reset()

        XCTAssertEqual(store.firstName, "")
        XCTAssertNil(store.difficulty)
        XCTAssertFalse(store.isComplete)
        XCTAssertFalse(OnboardingProfileStore(defaults: defaults).isComplete)
    }
}
