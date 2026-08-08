import XCTest
@testable import StartKind

final class ReschedulerTests: XCTestCase {
    let rescheduler = Rescheduler()

    private func base() -> NextStepProposal {
        NextStepProposal(title: "T", step: "S", timerMinutes: 12, stopCondition: "Stop", category: .bills)
    }

    func testSkippedProducesSmallerStep() {
        let result = rescheduler.reschedule(base(), language: "en", reason: .skipped)
        XCTAssertGreaterThan(result.proposal.shrinkLevel, .zero)
    }

    func testTooLargeProducesSmallerStep() {
        let result = rescheduler.reschedule(base(), language: "en", reason: .tooLarge)
        XCTAssertGreaterThan(result.proposal.shrinkLevel, .zero)
    }

    func testPausedMessageIsKind() {
        let result = rescheduler.reschedule(base(), language: "en", reason: .paused)
        XCTAssertTrue(result.message.lowercased().contains("paused") || result.message.lowercased().contains("smaller"))
    }

    func testNoShameInAnyReasonMessage() {
        for reason in [SkipReason.skipped, .paused, .tooLarge] {
            let result = rescheduler.reschedule(base(), language: "en", reason: reason)
            let lower = result.message.lowercased()
            XCTAssertFalse(lower.contains("fail"))
            XCTAssertFalse(lower.contains("missed"))
            XCTAssertFalse(lower.contains("streak"))
        }
    }

    func testRepeatedRescheduleStopsAtLevelThree() {
        var proposal = base()
        for _ in 0..<10 {
            let r = rescheduler.reschedule(proposal, language: "en", reason: .skipped)
            if r.proposal.shrinkLevel == proposal.shrinkLevel { break }
            proposal = r.proposal
        }
        XCTAssertLessThanOrEqual(proposal.shrinkLevel, .three)
    }

    func testChineseMessage() {
        let result = rescheduler.reschedule(base(), language: "zh-Hans", reason: .skipped)
        XCTAssertTrue(result.message.unicodeScalars.contains(where: { $0.value > 0x4E00 }))
    }
}
