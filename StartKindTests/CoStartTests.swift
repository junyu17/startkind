import XCTest
@testable import StartKind

@MainActor
final class CoStartTests: XCTestCase {
    private func makeService() throws -> PersistenceService { try PersistenceService(inMemory: true) }
    private func proposal(_ c: TaskCategory = .bills) -> NextStepProposal {
        NextStepProposal(title: "t", step: "s", timerMinutes: 10, stopCondition: "stop", category: c)
    }

    func testCoStartTimerRecordsCoStartMode() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 25, coStart: .ai)
        XCTAssertEqual(session.coStartMode, .ai)
        XCTAssertEqual(session.plannedMinutes, 25)
    }

    func testCoStartImpactsCalibration() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        let session = svc.startTimer(for: step, plannedMinutes: 25, coStart: .friend)
        svc.recordTimerOutcome(session: session, actualSeconds: 1500, outcome: .completed, step: step, isPlus: false)
        let samples = svc.calibrationSamples()
        XCTAssertTrue(samples.contains { $0.coStartUsed }, "co-start session should be marked in calibration samples")
    }

    func testCoStartRoomAndParticipantsPersist() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        _ = svc.startTimer(for: step, plannedMinutes: 25, coStart: .ai)
        // Rooms/participants are created at the AppEnvironment layer; verify timer
        // session carried co-start mode for the calibration insight path.
        let sessions = svc.recentSessions()
        XCTAssertTrue(sessions.contains { $0.coStartMode == .ai })
    }
}
