import XCTest
@testable import StartKind

final class LocalizationManagerTests: XCTestCase {
    func testLiveLanguageSwitch() {
        let manager = LocalizationManager()
        manager.setLanguage("en")
        XCTAssertEqual(manager.l("tab.start"), "Start")
        manager.setLanguage("zh-Hans")
        XCTAssertEqual(manager.l("tab.start"), "开始")
    }

    func testFormatArgsByLanguage() {
        let manager = LocalizationManager()
        manager.setLanguage("en")
        XCTAssertEqual(manager.l("nextstep.timer.minutes", [10]), "10 minutes")
        manager.setLanguage("zh-Hans")
        XCTAssertEqual(manager.l("nextstep.timer.minutes", [10]), "10 分钟")
    }

    func testUnknownKeyReturnsKey() {
        let manager = LocalizationManager()
        manager.setLanguage("en")
        XCTAssertEqual(manager.l("no.such.key.xyz"), "no.such.key.xyz")
    }

    func testLocaleUpdatesWithLanguage() {
        let manager = LocalizationManager()
        manager.setLanguage("zh-Hans")
        XCTAssertEqual(manager.language, "zh-Hans")
        manager.setLanguage("en")
        XCTAssertEqual(manager.language, "en")
    }
}
