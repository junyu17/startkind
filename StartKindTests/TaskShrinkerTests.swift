import XCTest
@testable import StartKind

final class TaskShrinkerTests: XCTestCase {
    let shrinker = TaskShrinker()

    private func base(_ category: TaskCategory = .bills) -> NextStepProposal {
        NextStepProposal(title: "T", step: "S", timerMinutes: 12, stopCondition: "Stop", category: category)
    }

    func testShrinkToLevelOne() {
        let s = shrinker.shrink(base(), to: .one, language: "en")
        XCTAssertEqual(s.shrinkLevel, .one)
        XCTAssertLessThanOrEqual(s.timerMinutes, 12)
        XCTAssertFalse(s.step.isEmpty)
        XCTAssertFalse(s.stopCondition.isEmpty)
    }

    func testShrinkToLevelThreeIsFrictionOnly() {
        let s = shrinker.shrink(base(), to: .three, language: "en")
        XCTAssertEqual(s.shrinkLevel, .three)
        XCTAssertLessThanOrEqual(s.timerMinutes, 5)
    }

    func testShrinkDoesNotEnlarge() {
        let alreadySmall = NextStepProposal(
            title: "T", step: "S", timerMinutes: 5, stopCondition: "Stop",
            category: .bills, shrinkLevel: .two
        )
        let s = shrinker.shrink(alreadySmall, to: .one, language: "en")
        XCTAssertEqual(s.shrinkLevel, .two, "should not enlarge back to one")
    }

    func testShrinkToSameLevelIsNoOp() {
        let p = base()
        let s = shrinker.shrink(p, to: .zero, language: "en")
        XCTAssertEqual(s.shrinkLevel, .zero)
        XCTAssertEqual(s.step, p.step)
    }

    func testNextLevelProgression() {
        XCTAssertEqual(shrinker.nextLevel(after: .zero), .one)
        XCTAssertEqual(shrinker.nextLevel(after: .one), .two)
        XCTAssertEqual(shrinker.nextLevel(after: .two), .three)
        XCTAssertEqual(shrinker.nextLevel(after: .three), .three)
    }

    func testChineseShrinkProducesChineseText() {
        let s = shrinker.shrink(base(), to: .one, language: "zh-Hans")
        XCTAssertTrue(s.step.unicodeScalars.contains(where: { $0.value > 0x4E00 }))
    }

    func testEveryCategoryShrinksToAllLevels() {
        for category in TaskCategory.allCases {
            for level in [ShrinkLevel.one, .two, .three] {
                let s = shrinker.shrink(base(category), to: level, language: "en")
                XCTAssertEqual(s.shrinkLevel, level, "\(category) \(level)")
                XCTAssertFalse(s.step.isEmpty)
            }
        }
    }
}
