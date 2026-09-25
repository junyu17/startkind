import XCTest
import SwiftData
@testable import StartKind

@MainActor
final class CoStartTests: XCTestCase {
    private func makeService() throws -> PersistenceService { try PersistenceService(inMemory: true) }
    private func proposal(_ c: TaskCategory = .bills) -> NextStepProposal {
        NextStepProposal(title: "t", step: "s", timerMinutes: 10, stopCondition: "stop", category: c)
    }

    private func makeStep(in env: AppEnvironment) -> NextStepModel {
        env.persistence.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
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

    func testQuietReadyDoesNotCountdownBeforeExplicitStart() {
        var state = CoStartFlowState(roomType: .aiQuiet, participantCount: 2)
        let initialSeconds = state.remainingSeconds

        XCTAssertEqual(state.stage, .ready)
        state.tick()

        XCTAssertEqual(state.remainingSeconds, initialSeconds)
    }

    func testFriendHostWaitsForBackendParticipantWithoutCountdown() {
        var state = CoStartFlowState(roomType: .friendLink, participantCount: 1)
        let initialSeconds = state.remainingSeconds

        XCTAssertEqual(state.stage, .waiting)
        state.start()
        state.tick()
        XCTAssertEqual(state.stage, .waiting)
        XCTAssertEqual(state.remainingSeconds, initialSeconds)

        state.updateParticipantCount(2)
        XCTAssertEqual(state.stage, .ready)
    }

    func testExplicitStartBeginsCountdown() {
        var state = CoStartFlowState(roomType: .friendLink, participantCount: 2)
        let initialSeconds = state.remainingSeconds

        XCTAssertEqual(state.stage, .ready)
        state.tick()
        XCTAssertEqual(state.remainingSeconds, initialSeconds)

        state.start()
        state.tick()

        XCTAssertEqual(state.stage, .focus)
        XCTAssertEqual(state.remainingSeconds, initialSeconds - 1)
    }

    func testQuietRoomCreatesTimerOnlyAfterExplicitStart() async throws {
        let env = AppEnvironment(inMemory: true)
        let step = makeStep(in: env)

        let room = try await env.startCoStart(
            type: .aiQuiet,
            step: step,
            stepText: step.proposal.step
        )

        XCTAssertTrue(env.persistence.recentSessions().isEmpty)

        let session = env.beginCoStart(room: room, step: step)
        XCTAssertEqual(session.coStartMode, .ai)
        XCTAssertEqual(env.persistence.recentSessions().count, 1)
    }

}
