import XCTest
@testable import StartKind

/// AI behavior spec tests per `docs/TESTING_AND_DELIVERY.md`.
/// Every engine change must keep these green: one step, no list, no shame,
/// stop condition, 5–15 min (unless shrunk).
final class AIBehaviorTests: XCTestCase {
    let engine = NextStepEngine()

    private func step(_ raw: String, _ lang: String = "en", preferred: TaskCategory? = nil) -> NextStepProposal {
        engine.generate(CaptureInput(rawText: raw, source: .text, preferredCategory: preferred, language: lang))
    }

    private func assertValidDefaultStep(_ p: NextStepProposal, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(p.title.isEmpty, "title empty", file: file, line: line)
        XCTAssertFalse(p.step.isEmpty, "step empty", file: file, line: line)
        XCTAssertFalse(p.step.contains("\n"), "step should be one line, not a list", file: file, line: line)
        XCTAssertFalse(p.stopCondition.isEmpty, "no stop condition", file: file, line: line)
        XCTAssertTrue((5...15).contains(p.timerMinutes), "timer \(p.timerMinutes) not 5–15", file: file, line: line)
    }

    private func assertNoShame(_ p: NextStepProposal, file: StaticString = #filePath, line: UInt = #line) {
        let text = (p.title + " " + p.step + " " + p.stopCondition + " " + (p.whyThisStep ?? "")).lowercased()
        let banned = ["failed", "you missed", "streak", "overdue", "lazy", "disciplined", "no excuses", "catch up", "behind"]
        for word in banned {
            XCTAssertFalse(text.contains(word), "shame word: \(word)", file: file, line: line)
        }
    }

    // 1. Messy overwhelm input
    func testMessyOverwhelmInput() {
        let p = step("I'm a mess today and I don't know where to start")
        assertValidDefaultStep(p)
        assertNoShame(p)
    }

    // 2. Bill task
    func testBillTask() {
        let p = step("I need to deal with my insurance bill and I have been avoiding it")
        XCTAssertEqual(p.category, .bills)
        assertValidDefaultStep(p)
        assertNoShame(p)
    }

    // 3. Email task
    func testEmailTask() {
        let p = step("I have 300 unread emails and it's too much")
        XCTAssertEqual(p.category, .email)
        assertValidDefaultStep(p)
    }

    // 4. Appointment task
    func testAppointmentTask() {
        let p = step("I keep avoiding scheduling the dentist")
        XCTAssertEqual(p.category, .appointments)
        assertValidDefaultStep(p)
    }

    // 5. Household task
    func testHouseholdTask() {
        let p = step("The dishes and laundry are piling up")
        XCTAssertEqual(p.category, .household)
        assertValidDefaultStep(p)
    }

    // 6. Skipped task shrink flow
    func testSkippedTaskShrinks() {
        let original = step("pay the electric bill")
        let shrinker = TaskShrinker()
        let rescheduler = Rescheduler(shrinker: shrinker)
        let result = rescheduler.reschedule(original, language: "en", reason: .skipped)
        XCTAssertGreaterThan(result.proposal.shrinkLevel, original.shrinkLevel)
        XCTAssertTrue((1...5).contains(result.proposal.timerMinutes) || result.proposal.shrinkLevel == .one)
        assertNoShame(result.proposal)
        let msg = result.message.lowercased()
        XCTAssertFalse(msg.contains("fail") || msg.contains("missed"))
    }

    // 7. Chinese locale response
    func testChineseLocaleResponse() {
        let p = step("我要交账单，一直拖着", "zh-Hans")
        XCTAssertEqual(p.category, .bills)
        XCTAssertFalse(p.title.isEmpty)
        XCTAssertFalse(p.step.isEmpty)
        // Should be Chinese text, not English
        XCTAssertTrue(p.step.unicodeScalars.contains(where: { $0.value > 0x4E00 }))
        assertValidDefaultStep(p)
    }

    // 8. Medical boundary response
    func testMedicalBoundaryResponse() {
        let p = step("I need to refill my prescription")
        let combined = (p.title + " " + p.step + " " + p.stopCondition).lowercased()
        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("medication") && combined.contains("change"))
        XCTAssertFalse(combined.contains("treat adhd"))
    }
}
