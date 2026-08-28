import XCTest
@testable import StartKind

/// Regression guards for the audit fixes: Keychain token storage, localized
/// error copy, and en/zh string-table parity.
final class AuditFixTests: XCTestCase {

    // MARK: - Keychain token storage

    private let probeKey = "sk_test_token_probe"

    override func tearDown() {
        TokenStore.set(nil as String?, for: probeKey)
        UserDefaults.standard.removeObject(forKey: probeKey)
        super.tearDown()
    }

    func testTokenStoreRoundTripsAndDeletes() {
        TokenStore.set(nil as String?, for: probeKey)
        XCTAssertNil(TokenStore.string(for: probeKey))

        TokenStore.set("first", for: probeKey)
        XCTAssertEqual(TokenStore.string(for: probeKey), "first")

        // Writing again must update in place, not fail as a duplicate item.
        TokenStore.set("second", for: probeKey)
        XCTAssertEqual(TokenStore.string(for: probeKey), "second")

        TokenStore.set(nil as String?, for: probeKey)
        XCTAssertNil(TokenStore.string(for: probeKey))
    }

    func testTokenStoreRoundTripsDoubles() {
        TokenStore.set(nil as String?, for: probeKey)
        TokenStore.set(1_234.5 as Double?, for: probeKey)
        XCTAssertEqual(TokenStore.double(for: probeKey) ?? 0, 1_234.5, accuracy: 0.001)
    }

    func testTokenStoreMigratesLegacyUserDefaultsValueAndClearsIt() {
        TokenStore.set(nil as String?, for: probeKey)
        UserDefaults.standard.set("legacy-token", forKey: probeKey)

        TokenStore.migrateFromUserDefaults(keys: [probeKey])

        XCTAssertEqual(TokenStore.string(for: probeKey), "legacy-token")
        XCTAssertNil(UserDefaults.standard.string(forKey: probeKey), "The plaintext copy must not survive migration")
    }

    func testTokenStoreMigrationKeepsExistingKeychainValue() {
        TokenStore.set("keychain-token", for: probeKey)
        UserDefaults.standard.set("stale-token", forKey: probeKey)

        TokenStore.migrateFromUserDefaults(keys: [probeKey])

        XCTAssertEqual(TokenStore.string(for: probeKey), "keychain-token")
        XCTAssertNil(UserDefaults.standard.string(forKey: probeKey))
    }

    // MARK: - Localized error copy

    func testSurfacedErrorsAreLocalizedNotRawKeys() {
        LocalizationManager.shared.setLanguage("en")
        let errors: [LocalizedError] = [
            UsageError.stepLimitReached,
            UsageError.adminLimitReached,
            SpeechError.notAuthorized,
            SpeechError.microphoneNotAuthorized,
            SpeechError.notAvailable,
            SpeechError.engineFailure
        ]
        for error in errors {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty)
            XCTAssertFalse(
                description.hasPrefix("error."),
                "\(error) fell through to its raw key instead of a localized string"
            )
        }
    }

    func testErrorCopyFollowsTheInAppLanguage() {
        LocalizationManager.shared.setLanguage("zh-Hans")
        defer { LocalizationManager.shared.setLanguage("en") }
        let zh = UsageError.stepLimitReached.errorDescription ?? ""
        XCTAssertTrue(
            zh.contains(where: { $0.unicodeScalars.contains { (0x4E00...0x9FFF).contains(Int($0.value)) } }),
            "Error copy should follow the in-app language picker, not the system language"
        )
    }

    // MARK: - String table parity

    func testEnglishAndChineseTablesDefineTheSameKeys() throws {
        let english = try Self.keys(language: "en")
        let chinese = try Self.keys(language: "zh-Hans")
        XCTAssertFalse(english.isEmpty)
        XCTAssertEqual(
            english.symmetricDifference(chinese),
            [],
            "Every localized key must exist in both tables"
        )
    }

    private static func keys(language: String) throws -> Set<String> {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(language).lproj"),
            "Missing \(language) string table"
        )
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        return Set(table.keys)
    }
}
