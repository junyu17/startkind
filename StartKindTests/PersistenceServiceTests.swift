import XCTest
import SwiftData
@testable import StartKind

@MainActor
final class PersistenceServiceTests: XCTestCase {
    private func makeService() throws -> PersistenceService {
        try PersistenceService(inMemory: true)
    }

    private func sampleProposal(_ category: TaskCategory = .bills) -> NextStepProposal {
        NextStepProposal(title: "Find the bill", step: "Open email", timerMinutes: 10, stopCondition: "Stop when found", category: category)
    }

    func testRoundTripNextStep() throws {
        let svc = try makeService()
        let capture = svc.saveCapture(rawText: "pay bill", source: .text, language: "en")
        let step = svc.saveNextStep(proposal: sampleProposal(), capture: capture, taskTitle: "Find the bill")
        XCTAssertEqual(step.category, .bills)
        XCTAssertEqual(step.proposal.step, "Open email")
        XCTAssertEqual(step.proposal.stopCondition, "Stop when found")
    }

    func testFetchNextStepById() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(), capture: nil, taskTitle: "T")
        let fetched = svc.fetchNextStep(id: step.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, step.id)
    }

    func testFreeKeepsSingleActiveRecoveryCapsule() throws {
        let svc = try makeService()
        let step1 = svc.saveNextStep(proposal: sampleProposal(.bills), capture: nil, taskTitle: "T1")
        let step2 = svc.saveNextStep(proposal: sampleProposal(.email), capture: nil, taskTitle: "T2")
        svc.upsertRecoveryCapsule(for: step1, isPlus: false)
        svc.upsertRecoveryCapsule(for: step2, isPlus: false)

        let descriptor = FetchDescriptor<RecoveryCapsuleModel>(predicate: #Predicate { $0.active })
        let active = (try? svc.context.fetch(descriptor)) ?? []
        XCTAssertEqual(active.count, 1, "Free should keep at most one active capsule")
        XCTAssertEqual(active.first?.resumeCategory, .email)
    }

    func testPlusAllowsMultipleActiveCapsules() throws {
        let svc = try makeService()
        let step1 = svc.saveNextStep(proposal: sampleProposal(.bills), capture: nil, taskTitle: "T1")
        let step2 = svc.saveNextStep(proposal: sampleProposal(.email), capture: nil, taskTitle: "T2")
        svc.upsertRecoveryCapsule(for: step1, isPlus: true)
        svc.upsertRecoveryCapsule(for: step2, isPlus: true)

        let descriptor = FetchDescriptor<RecoveryCapsuleModel>(predicate: #Predicate { $0.active })
        let active = (try? svc.context.fetch(descriptor)) ?? []
        XCTAssertEqual(active.count, 2)
    }

    func testTimerOutcomeProducesCalibrationSample() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(.bills), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)
        svc.recordTimerOutcome(session: session, actualSeconds: 900, outcome: .completed, step: step, isPlus: false)

        let samples = svc.calibrationSamples()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].category, .bills)
        XCTAssertEqual(samples[0].actualSeconds, 900)
        XCTAssertEqual(samples[0].outcome, .completed)
    }

    func testCompletedTimerClearsRecoveryCapsule() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)
        // First pause -> creates capsule
        svc.recordTimerOutcome(session: session, actualSeconds: 120, outcome: .paused, step: step, isPlus: false)
        XCTAssertNotNil(svc.activeRecoveryCapsule())
        // Complete a new session -> clears capsule
        let session2 = svc.startTimer(for: step, plannedMinutes: 5)
        svc.recordTimerOutcome(session: session2, actualSeconds: 300, outcome: .completed, step: step, isPlus: false)
        XCTAssertNil(svc.activeRecoveryCapsule())
    }

    func testPausedTimerStoresSmallerRecoveryStep() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(.insurance), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)
        let result = Rescheduler().reschedule(step.proposal, language: "en", reason: .paused)
        svc.updateNextStep(step, proposal: result.proposal)

        svc.recordTimerOutcome(session: session, actualSeconds: 120, outcome: .paused, step: step, isPlus: false)

        let capsule = try XCTUnwrap(svc.activeRecoveryCapsule())
        XCTAssertEqual(capsule.resumeProposal.shrinkLevel, .one)
        XCTAssertEqual(capsule.resumeProposal.step, result.proposal.step)
    }

    func testPausedTimerStoresBlockerInRecoveryCapsule() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(.insurance), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)

        svc.recordTimerOutcome(session: session, actualSeconds: 120, outcome: .paused, step: step, isPlus: false, blocker: .needDocument)

        let capsule = try XCTUnwrap(svc.activeRecoveryCapsule())
        XCTAssertEqual(capsule.blockerReason, .needDocument)
        XCTAssertEqual(capsule.relatedDraft, RecoveryCapsuleModel.blockerDraft(.needDocument))
    }

    func testAbandonedTimerStoresBlockerInRecoveryCapsule() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(.household), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)

        svc.recordTimerOutcome(session: session, actualSeconds: 30, outcome: .abandoned, step: step, isPlus: false, blocker: .tooBig)

        let capsule = try XCTUnwrap(svc.activeRecoveryCapsule())
        XCTAssertEqual(step.status, .skipped)
        XCTAssertEqual(capsule.blockerReason, .tooBig)
    }

    func testDeleteAllDataClearsHistory() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)
        svc.recordTimerOutcome(session: session, actualSeconds: 300, outcome: .completed, step: step, isPlus: false)
        XCTAssertFalse(svc.recentSessions().isEmpty)

        svc.deleteAllData()
        XCTAssertTrue(svc.recentSessions().isEmpty)
        XCTAssertEqual(svc.profile?.entitlement, .free)
    }

    func testExportJSONIsValid() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: sampleProposal(), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 10)
        svc.recordTimerOutcome(session: session, actualSeconds: 300, outcome: .completed, step: step, isPlus: false)
        let json = svc.exportJSON()
        XCTAssertFalse(json.isEmpty)
        let data = json.data(using: .utf8)!
        let object = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(object)
    }
}
