import XCTest
@testable import StartKind

final class NextStepEngineTests: XCTestCase {
    let engine = NextStepEngine()

    func testDetectsBillsByKeyword() {
        XCTAssertEqual(engine.detectCategory(in: "pay the electric bill", preferred: nil), .bills)
        XCTAssertEqual(engine.detectCategory(in: "缴费", preferred: nil), .bills)
    }

    func testDetectsBanking() {
        XCTAssertEqual(engine.detectCategory(in: "transfer money to bank", preferred: nil), .banking)
    }

    func testDetectsReturns() {
        XCTAssertEqual(engine.detectCategory(in: "I need to return this package", preferred: nil), .returns)
    }

    func testPreferredCategoryOverridesDetection() {
        XCTAssertEqual(engine.detectCategory(in: "blah blah", preferred: .medical), .medical)
    }

    func testFallbackIsOther() {
        XCTAssertEqual(engine.detectCategory(in: "xyz qwerty", preferred: nil), .other)
    }

    func testGenerateUsesCalibrationMultiplier() {
        let input = CaptureInput(rawText: "pay bill", source: .text, preferredCategory: nil, language: "en")
        let base = engine.generate(input, calibrationMultiplier: 1.0)
        let scaled = engine.generate(input, calibrationMultiplier: 1.5)
        XCTAssertGreaterThanOrEqual(scaled.timerMinutes, base.timerMinutes)
    }

    func testGenerateClampsTimerTo5And25() {
        let input = CaptureInput(rawText: "pay bill", source: .text, preferredCategory: nil, language: "en")
        let big = engine.generate(input, calibrationMultiplier: 3.0)
        XCTAssertLessThanOrEqual(big.timerMinutes, 25)
        let tiny = engine.generate(input, calibrationMultiplier: 0.1)
        XCTAssertGreaterThanOrEqual(tiny.timerMinutes, 5)
    }

    func testEveryCategoryProducesValidStep() {
        for category in TaskCategory.allCases {
            let p = engine.generate(CaptureInput(rawText: category.rawValue, source: .text, preferredCategory: category, language: "en"))
            XCTAssertEqual(p.category, category)
            XCTAssertFalse(p.title.isEmpty, "no title for \(category)")
            XCTAssertFalse(p.step.isEmpty, "no step for \(category)")
            XCTAssertFalse(p.stopCondition.isEmpty, "no stop for \(category)")
            XCTAssertTrue((5...15).contains(p.timerMinutes), "timer \(p.timerMinutes) for \(category)")
        }
    }

    func testGeneratedByIsLocalTemplate() {
        let p = engine.generate(CaptureInput(rawText: "bill", source: .text, preferredCategory: nil, language: "en"))
        XCTAssertEqual(p.generatedBy, .localTemplate)
    }
}
