import Foundation
import SwiftData

/// Central data access layer over SwiftData. All access is main-actor bound.
@MainActor
final class PersistenceService: ObservableObject {
    let container: ModelContainer
    @Published private(set) var profile: UserProfileModel?

    var context: ModelContext { container.mainContext }

    /// Private data that follows the person across their devices via their own
    /// iCloud account. No server of ours ever sees it.
    private static let syncedModels: [any PersistentModel.Type] = [
        UserProfileModel.self,
        CaptureModel.self,
        TaskItemModel.self,
        NextStepModel.self,
        TimerSessionModel.self,
        TimeCalibrationProfileModel.self,
        RecoveryCapsuleModel.self,
        AdminArtifactModel.self
    ]

    /// Co-start rooms are shared, short-lived server state, not personal
    /// history. They stay on this device and are never pushed to CloudKit.
    private static let localOnlyModels: [any PersistentModel.Type] = [
        CoStartRoomModel.self,
        CoStartParticipantModel.self
    ]

    private static var fullSchema: Schema { Schema(syncedModels + localOnlyModels) }

    private static let cloudKitContainerID = "iCloud.ren.startkind"

    init(inMemory: Bool = false) throws {
        let schema = Self.fullSchema
        if inMemory {
            // Tests and UI-test runs must never touch a real iCloud account.
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: [config])
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? URL.temporaryDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            container = try Self.diskContainer(in: dir)
        }
        profile = ensureProfile()
    }

    /// A store that cannot be opened - corrupted on disk, or written by an
    /// incompatible schema - must not make the app unlaunchable forever. Move
    /// the unreadable files aside once and start clean instead.
    private static func diskContainer(in dir: URL) throws -> ModelContainer {
        do {
            return try makeContainer(in: dir)
        } catch {
            quarantineStore(at: dir.appendingPathComponent("StartKind.store"))
            quarantineStore(at: dir.appendingPathComponent("StartKindCoStart.store"))
            return try makeContainer(in: dir)
        }
    }

    private static func makeContainer(in dir: URL) throws -> ModelContainer {
        let synced = ModelConfiguration(
            "StartKindSynced",
            schema: Schema(syncedModels),
            url: dir.appendingPathComponent("StartKind.store"),
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        let localOnly = ModelConfiguration(
            "StartKindLocal",
            schema: Schema(localOnlyModels),
            url: dir.appendingPathComponent("StartKindCoStart.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: fullSchema, configurations: [synced, localOnly])
    }

    private static func quarantineStore(at url: URL) {
        let manager = FileManager.default
        let quarantined = url.deletingLastPathComponent().appendingPathComponent("StartKind-unreadable.store")
        // SwiftData keeps -shm/-wal sidecars next to the store; move them together.
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard manager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: quarantined.path + suffix)
            try? manager.removeItem(at: destination)
            try? manager.moveItem(at: source, to: destination)
        }
    }

    // MARK: - Profile

    @discardableResult
    func ensureProfile() -> UserProfileModel {
        if let existing = profile { return existing }
        let descriptor = FetchDescriptor<UserProfileModel>()
        if let found = try? context.fetch(descriptor).first {
            profile = found
            return found
        }
        let new = UserProfileModel()
        context.insert(new)
        try? context.save()
        profile = new
        return new
    }

    func updateProfile(locale: String? = nil, tone: PreferredTone? = nil, entitlement: EntitlementState? = nil) {
        let p = ensureProfile()
        if let locale { p.locale = locale }
        if let tone { p.tone = tone }
        if let entitlement { p.entitlement = entitlement }
        p.updatedAt = .now
        try? context.save()
    }

    var userId: UUID { ensureProfile().id }

    // MARK: - Capture & NextStep

    @discardableResult
    func saveCapture(rawText: String, source: CaptureSource, language: String) -> CaptureModel {
        let capture = CaptureModel(userId: userId, source: source, rawText: rawText, language: language)
        context.insert(capture)
        try? context.save()
        return capture
    }

    @discardableResult
    func saveNextStep(
        proposal: NextStepProposal,
        capture: CaptureModel?,
        taskTitle: String
    ) -> NextStepModel {
        let task = TaskItemModel(
            userId: userId,
            captureId: capture?.id,
            title: taskTitle,
            category: proposal.category
        )
        context.insert(task)
        let step = NextStepModel(taskId: task.id, userId: userId, proposal: proposal)
        context.insert(step)
        try? context.save()
        return step
    }

    func updateNextStep(_ step: NextStepModel, proposal: NextStepProposal) {
        step.title = proposal.title
        step.stepText = proposal.step
        step.stopCondition = proposal.stopCondition
        step.category = proposal.category
        step.shrinkLevel = proposal.shrinkLevel
        step.targetMinutes = proposal.timerMinutes
        step.whyThisStep = proposal.whyThisStep
        step.updatedAt = .now
        try? context.save()
    }

    func fetchNextStep(id: UUID) -> NextStepModel? {
        let descriptor = FetchDescriptor<NextStepModel>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func recentNextSteps(days: Int = 2) -> [NextStepModel] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let id = userId
        let descriptor = FetchDescriptor<NextStepModel>(
            predicate: #Predicate { $0.userId == id && $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Timer

    @discardableResult
    func startTimer(for step: NextStepModel, plannedMinutes: Int, coStart: CoStartMode = .none) -> TimerSessionModel {
        step.status = .started
        step.startedAt = .now
        step.updatedAt = .now
        let session = TimerSessionModel(
            nextStepId: step.id,
            userId: userId,
            plannedMinutes: plannedMinutes,
            outcome: .paused,
            coStartMode: coStart,
            category: step.category,
            estimatedMinutes: step.estimatedMinutes
        )
        context.insert(session)
        try? context.save()
        return session
    }

    func recordTimerOutcome(
        session: TimerSessionModel,
        actualSeconds: Int,
        outcome: TimerOutcome,
        step: NextStepModel?,
        isPlus: Bool
    ) {
        recordTimerOutcome(session: session, actualSeconds: actualSeconds, outcome: outcome, step: step, isPlus: isPlus, blocker: nil)
    }

    func recordTimerOutcome(
        session: TimerSessionModel,
        actualSeconds: Int,
        outcome: TimerOutcome,
        step: NextStepModel?,
        isPlus: Bool,
        blocker: BlockerReason?
    ) {
        recordTimerOutcome(session: session, actualSeconds: actualSeconds, outcome: outcome, step: step, isPlus: isPlus, blocker: blocker, returnNote: nil)
    }

    func recordTimerOutcome(
        session: TimerSessionModel,
        actualSeconds: Int,
        outcome: TimerOutcome,
        step: NextStepModel?,
        isPlus: Bool,
        blocker: BlockerReason?,
        returnNote: String?
    ) {
        session.actualSeconds = actualSeconds
        session.outcome = outcome
        session.endedAt = .now
        switch outcome {
        case .completed:
            step?.status = .completed
            step?.completedAt = .now
            clearActiveRecoveryCapsule()
        case .partial, .paused:
            step?.status = .paused
            if let step { upsertRecoveryCapsule(for: step, isPlus: isPlus, blocker: blocker, returnNote: returnNote) }
        case .abandoned:
            step?.status = .skipped
            if let step { upsertRecoveryCapsule(for: step, isPlus: isPlus, blocker: blocker, returnNote: returnNote) }
        }
        step?.updatedAt = .now
        try? context.save()
    }

    // MARK: - Recovery Capsule

    func upsertRecoveryCapsule(for step: NextStepModel, isPlus: Bool, blocker: BlockerReason? = nil, returnNote: String? = nil) {
        let id = userId
        // Free: keep at most one active capsule.
        if !isPlus {
            let descriptor = FetchDescriptor<RecoveryCapsuleModel>(
                predicate: #Predicate { $0.active && $0.userId == id }
            )
            if let existing = try? context.fetch(descriptor) {
                for capsule in existing { capsule.active = false }
            }
        }
        let proposal = step.proposal
        let capsule = RecoveryCapsuleModel(
            userId: userId,
            taskId: step.taskId,
            lastStepId: step.id,
            stateSummary: step.title,
            resumeStepText: proposal.step,
            resumeTitle: proposal.title,
            resumeStopCondition: proposal.stopCondition,
            resumeTimerMinutes: proposal.timerMinutes,
            resumeCategory: proposal.category,
            resumeShrinkLevel: proposal.shrinkLevel,
            relatedDraft: RecoveryCapsuleModel.metadataDraft(blocker: blocker, note: returnNote)
        )
        context.insert(capsule)
        try? context.save()
    }

    func recoveryCapsules() -> [RecoveryCapsuleModel] {
        let id = userId
        let descriptor = FetchDescriptor<RecoveryCapsuleModel>(
            predicate: #Predicate { $0.userId == id },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func activeRecoveryCapsule() -> RecoveryCapsuleModel? {
        let id = userId
        let descriptor = FetchDescriptor<RecoveryCapsuleModel>(
            predicate: #Predicate { $0.active && $0.userId == id },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    func clearActiveRecoveryCapsule() {
        let id = userId
        let descriptor = FetchDescriptor<RecoveryCapsuleModel>(
            predicate: #Predicate { $0.active && $0.userId == id }
        )
        if let capsules = try? context.fetch(descriptor) {
            for capsule in capsules { capsule.active = false }
            try? context.save()
        }
    }

    // MARK: - History & Calibration

    func recentSessions(days: Int = UsageLimits.freeHistoryDays) -> [TimerSessionModel] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let id = userId
        let descriptor = FetchDescriptor<TimerSessionModel>(
            predicate: #Predicate { $0.userId == id && $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func calibrationSamples() -> [CalibrationSample] {
        recentSessions().map { session in
            CalibrationSample(
                category: session.category,
                estimatedMinutes: session.estimatedMinutes,
                actualSeconds: session.actualSeconds,
                outcome: session.outcome,
                startHour: Calendar.current.component(.hour, from: session.createdAt),
                coStartUsed: session.coStartMode != .none
            )
        }
    }

    func calibrationSnapshots() -> [CalibrationSnapshot] {
        let samples = calibrationSamples()
        let calibrator = TimeCalibrator()
        return Set(samples.map(\.category))
            .sorted(by: { $0.displayName < $1.displayName })
            .map { calibrator.snapshot(for: $0, in: samples) }
    }

    // MARK: - Admin Artifacts

    @discardableResult
    func saveAdminArtifact(result: AdminParseResult) -> AdminArtifactModel {
        let artifact = AdminArtifactModel(userId: userId, result: result)
        context.insert(artifact)
        try? context.save()
        return artifact
    }

    // MARK: - Data control

    func deleteAllData() {
        try? context.delete(model: CoStartParticipantModel.self)
        try? context.delete(model: CoStartRoomModel.self)
        try? context.delete(model: AdminArtifactModel.self)
        try? context.delete(model: RecoveryCapsuleModel.self)
        try? context.delete(model: TimeCalibrationProfileModel.self)
        try? context.delete(model: TimerSessionModel.self)
        try? context.delete(model: NextStepModel.self)
        try? context.delete(model: TaskItemModel.self)
        try? context.delete(model: CaptureModel.self)
        // Reset profile entitlement, keep the profile row.
        let p = ensureProfile()
        p.entitlement = .free
        try? context.save()
        profile = p
    }

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sessions = recentSessions(days: UsageLimits.freeHistoryDays).map { session -> [String: String] in
            [
                "date": ISO8601DateFormatter().string(from: session.createdAt),
                "category": session.category.rawValue,
                "planned_minutes": String(session.plannedMinutes),
                "actual_seconds": String(session.actualSeconds),
                "outcome": session.outcome.rawValue
            ]
        }
        let payload: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: .now),
            "locale": ensureProfile().locale,
            "timer_sessions": sessions
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
