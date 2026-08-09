import Foundation
import SwiftData

// MARK: - UserProfile

/// Local user profile. Singleton-per-device; mirrored to Supabase for Plus sync.
@Model
final class UserProfileModel {
    @Attribute(.unique) var id: UUID
    var locale: String
    var timezone: String
    var entitlementState: String
    var preferredTone: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        locale: String = "en",
        timezone: String = TimeZone.current.identifier,
        entitlementState: EntitlementState = .free,
        preferredTone: PreferredTone = .neutral,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.locale = locale
        self.timezone = timezone
        self.entitlementState = entitlementState.rawValue
        self.preferredTone = preferredTone.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var entitlement: EntitlementState {
        get { EntitlementState(rawValue: entitlementState) ?? .free }
        set { entitlementState = newValue.rawValue }
    }

    var tone: PreferredTone {
        get { PreferredTone(rawValue: preferredTone) ?? .neutral }
        set { preferredTone = newValue.rawValue }
    }
}

// MARK: - Capture

@Model
final class CaptureModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var sourceType: String
    var rawText: String
    var language: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        source: CaptureSource,
        rawText: String,
        language: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.sourceType = source.rawValue
        self.rawText = rawText
        self.language = language
        self.createdAt = createdAt
    }

    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceType) ?? .text }
        set { sourceType = newValue.rawValue }
    }
}

// MARK: - TaskItem

@Model
final class TaskItemModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var captureId: UUID?
    var title: String
    var categoryValue: String
    var emotionalLoadValue: String
    var statusValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        captureId: UUID? = nil,
        title: String,
        category: TaskCategory = .other,
        emotionalLoad: EmotionalLoad = .medium,
        status: TaskStatus = .active,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.captureId = captureId
        self.title = title
        self.categoryValue = category.rawValue
        self.emotionalLoadValue = emotionalLoad.rawValue
        self.statusValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryValue) ?? .other }
        set { categoryValue = newValue.rawValue }
    }

    var emotionalLoad: EmotionalLoad {
        get { EmotionalLoad(rawValue: emotionalLoadValue) ?? .medium }
        set { emotionalLoadValue = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusValue) ?? .active }
        set { statusValue = newValue.rawValue }
    }
}

// MARK: - NextStep

@Model
final class NextStepModel {
    @Attribute(.unique) var id: UUID
    var taskId: UUID?
    var userId: UUID
    var title: String
    var stepText: String
    var stopCondition: String
    var categoryValue: String
    var shrinkLevelValue: Int
    var estimatedMinutes: Int
    var targetMinutes: Int
    var statusValue: String
    var generatedByValue: String
    var whyThisStep: String?
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        userId: UUID,
        proposal: NextStepProposal,
        status: NextStepStatus = .suggested,
        createdAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.title = proposal.title
        self.stepText = proposal.step
        self.stopCondition = proposal.stopCondition
        self.categoryValue = proposal.category.rawValue
        self.shrinkLevelValue = proposal.shrinkLevel.rawValue
        self.estimatedMinutes = proposal.timerMinutes
        self.targetMinutes = proposal.timerMinutes
        self.statusValue = status.rawValue
        self.generatedByValue = proposal.generatedBy.rawValue
        self.whyThisStep = proposal.whyThisStep
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryValue) ?? .other }
        set { categoryValue = newValue.rawValue }
    }

    var shrinkLevel: ShrinkLevel {
        get { ShrinkLevel(rawValue: shrinkLevelValue) ?? .zero }
        set { shrinkLevelValue = newValue.rawValue }
    }

    var status: NextStepStatus {
        get { NextStepStatus(rawValue: statusValue) ?? .suggested }
        set { statusValue = newValue.rawValue }
    }

    var generatedBy: NextStepGeneratedBy {
        get { NextStepGeneratedBy(rawValue: generatedByValue) ?? .localTemplate }
        set { generatedByValue = newValue.rawValue }
    }

    /// Rebuild the value-type proposal for display.
    var proposal: NextStepProposal {
        NextStepProposal(
            id: id,
            title: title,
            step: stepText,
            timerMinutes: targetMinutes,
            stopCondition: stopCondition,
            category: category,
            shrinkLevel: shrinkLevel,
            generatedBy: generatedBy,
            whyThisStep: whyThisStep
        )
    }
}

// MARK: - TimerSession

@Model
final class TimerSessionModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var nextStepId: UUID?
    var userId: UUID
    var plannedMinutes: Int
    var actualSeconds: Int
    var outcomeValue: String
    var coStartModeValue: String
    var categoryValue: String
    var estimatedMinutes: Int
    var createdAt: Date
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        nextStepId: UUID? = nil,
        userId: UUID,
        plannedMinutes: Int,
        actualSeconds: Int = 0,
        outcome: TimerOutcome = .paused,
        coStartMode: CoStartMode = .none,
        category: TaskCategory = .other,
        estimatedMinutes: Int = 10,
        createdAt: Date = .now,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.nextStepId = nextStepId
        self.userId = userId
        self.plannedMinutes = plannedMinutes
        self.actualSeconds = actualSeconds
        self.outcomeValue = outcome.rawValue
        self.coStartModeValue = coStartMode.rawValue
        self.categoryValue = category.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = createdAt
        self.endedAt = endedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryValue) ?? .other }
        set { categoryValue = newValue.rawValue }
    }

    var outcome: TimerOutcome {
        get { TimerOutcome(rawValue: outcomeValue) ?? .paused }
        set { outcomeValue = newValue.rawValue }
    }

    var coStartMode: CoStartMode {
        get { CoStartMode(rawValue: coStartModeValue) ?? .none }
        set { coStartModeValue = newValue.rawValue }
    }
}

// MARK: - TimeCalibrationProfile

@Model
final class TimeCalibrationProfileModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var categoryValue: String
    var estimateMultiplier: Double
    var medianActualMinutes: Double?
    var completionRate: Double
    var bestStartWindow: String?
    var sampleCount: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        category: TaskCategory,
        estimateMultiplier: Double = 1.0,
        medianActualMinutes: Double? = nil,
        completionRate: Double = 0,
        bestStartWindow: String? = nil,
        sampleCount: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.categoryValue = category.rawValue
        self.estimateMultiplier = estimateMultiplier
        self.medianActualMinutes = medianActualMinutes
        self.completionRate = completionRate
        self.bestStartWindow = bestStartWindow
        self.sampleCount = sampleCount
        self.updatedAt = updatedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryValue) ?? .other }
        set { categoryValue = newValue.rawValue }
    }

    var snapshot: CalibrationSnapshot {
        CalibrationSnapshot(
            id: id,
            category: category,
            estimateMultiplier: estimateMultiplier,
            medianActualMinutes: medianActualMinutes,
            completionRate: completionRate,
            bestStartWindow: bestStartWindow,
            sampleCount: sampleCount
        )
    }
}

// MARK: - RecoveryCapsule

@Model
final class RecoveryCapsuleModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var taskId: UUID?
    var lastStepId: UUID?
    var stateSummary: String
    var resumeStepText: String
    var resumeTitle: String
    var resumeStopCondition: String
    var resumeTimerMinutes: Int
    var resumeCategoryValue: String
    var resumeShrinkLevelValue: Int = 0
    var relatedLink: String?
    var relatedDraft: String?
    var active: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        taskId: UUID? = nil,
        lastStepId: UUID? = nil,
        stateSummary: String,
        resumeStepText: String,
        resumeTitle: String,
        resumeStopCondition: String,
        resumeTimerMinutes: Int,
        resumeCategory: TaskCategory,
        resumeShrinkLevel: ShrinkLevel = .zero,
        relatedLink: String? = nil,
        relatedDraft: String? = nil,
        active: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.taskId = taskId
        self.lastStepId = lastStepId
        self.stateSummary = stateSummary
        self.resumeStepText = resumeStepText
        self.resumeTitle = resumeTitle
        self.resumeStopCondition = resumeStopCondition
        self.resumeTimerMinutes = resumeTimerMinutes
        self.resumeCategoryValue = resumeCategory.rawValue
        self.resumeShrinkLevelValue = resumeShrinkLevel.rawValue
        self.relatedLink = relatedLink
        self.relatedDraft = relatedDraft
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var resumeCategory: TaskCategory {
        get { TaskCategory(rawValue: resumeCategoryValue) ?? .other }
        set { resumeCategoryValue = newValue.rawValue }
    }

    var resumeShrinkLevel: ShrinkLevel {
        get { ShrinkLevel(rawValue: resumeShrinkLevelValue) ?? .zero }
        set { resumeShrinkLevelValue = newValue.rawValue }
    }

    /// Rebuild a proposal for resuming.
    var resumeProposal: NextStepProposal {
        NextStepProposal(
            id: lastStepId ?? UUID(),
            title: resumeTitle,
            step: resumeStepText,
            timerMinutes: resumeTimerMinutes,
            stopCondition: resumeStopCondition,
            category: resumeCategory,
            shrinkLevel: resumeShrinkLevel,
            generatedBy: .user
        )
    }

    var blockerReason: BlockerReason? {
        Self.decodeBlocker(from: relatedDraft)
    }

    static func blockerDraft(_ reason: BlockerReason) -> String {
        "blocker:\(reason.rawValue)"
    }

    static func decodeBlocker(from value: String?) -> BlockerReason? {
        guard let value, value.hasPrefix("blocker:") else { return nil }
        return BlockerReason(rawValue: String(value.dropFirst("blocker:".count)))
    }
}

// MARK: - AdminArtifact

@Model
final class AdminArtifactModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var taskId: UUID?
    var artifactTypeValue: String
    var extractedDueDate: Date?
    var extractedAmount: String?
    var extractedContact: String?
    var extractedURL: String?
    var requiredDocuments: [String]
    var oneNextStepTitle: String
    var oneNextStepText: String
    var oneNextStepStop: String
    var oneNextStepTimer: Int
    var oneNextStepCategoryValue: String = TaskCategory.other.rawValue
    var oneNextStepShrinkLevelValue: Int = 0
    var confidence: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        taskId: UUID? = nil,
        result: AdminParseResult,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.taskId = taskId
        self.artifactTypeValue = result.artifactType.rawValue
        self.extractedDueDate = result.dueDate
        self.extractedAmount = result.amount
        self.extractedContact = result.contact
        self.extractedURL = result.linkOrPhone
        self.requiredDocuments = result.requiredDocuments
        self.oneNextStepTitle = result.oneNextStep.title
        self.oneNextStepText = result.oneNextStep.step
        self.oneNextStepStop = result.oneNextStep.stopCondition
        self.oneNextStepTimer = result.oneNextStep.timerMinutes
        self.oneNextStepCategoryValue = result.oneNextStep.category.rawValue
        self.oneNextStepShrinkLevelValue = result.oneNextStep.shrinkLevel.rawValue
        self.confidence = result.confidence
        self.createdAt = createdAt
    }

    var artifactType: AdminArtifactType {
        get { AdminArtifactType(rawValue: artifactTypeValue) ?? .other }
        set { artifactTypeValue = newValue.rawValue }
    }

    var oneNextStep: NextStepProposal {
        NextStepProposal(
            title: oneNextStepTitle,
            step: oneNextStepText,
            timerMinutes: oneNextStepTimer,
            stopCondition: oneNextStepStop,
            category: TaskCategory(rawValue: oneNextStepCategoryValue) ?? .other,
            shrinkLevel: ShrinkLevel(rawValue: oneNextStepShrinkLevelValue) ?? .zero,
            generatedBy: .cloudAI
        )
    }
}

// MARK: - CoStart

@Model
final class CoStartRoomModel {
    @Attribute(.unique) var id: UUID
    var hostUserId: UUID
    var roomTypeValue: String
    var durationMinutes: Int
    var statusValue: String
    var inviteTokenHash: String?
    var roomCode: String?
    var createdAt: Date
    var startsAt: Date?
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        hostUserId: UUID,
        roomType: CoStartRoomType,
        durationMinutes: Int = 25,
        status: CoStartRoomStatus = .scheduled,
        inviteTokenHash: String? = nil,
        roomCode: String? = nil,
        createdAt: Date = .now,
        startsAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.hostUserId = hostUserId
        self.roomTypeValue = roomType.rawValue
        self.durationMinutes = durationMinutes
        self.statusValue = status.rawValue
        self.inviteTokenHash = inviteTokenHash
        self.roomCode = roomCode
        self.createdAt = createdAt
        self.startsAt = startsAt
        self.endedAt = endedAt
    }

    var roomType: CoStartRoomType {
        get { CoStartRoomType(rawValue: roomTypeValue) ?? .quietRoom }
        set { roomTypeValue = newValue.rawValue }
    }

    var status: CoStartRoomStatus {
        get { CoStartRoomStatus(rawValue: statusValue) ?? .scheduled }
        set { statusValue = newValue.rawValue }
    }
}

@Model
final class CoStartParticipantModel {
    @Attribute(.unique) var id: UUID
    var roomId: UUID
    var userIdNullable: UUID?
    var displayName: String
    var statedStep: String
    var outcomeValue: String?
    var joinedAt: Date
    var leftAt: Date?

    init(
        id: UUID = UUID(),
        roomId: UUID,
        userId: UUID? = nil,
        displayName: String,
        statedStep: String,
        outcome: TimerOutcome? = nil,
        joinedAt: Date = .now,
        leftAt: Date? = nil
    ) {
        self.id = id
        self.roomId = roomId
        self.userIdNullable = userId
        self.displayName = displayName
        self.statedStep = statedStep
        self.outcomeValue = outcome?.rawValue
        self.joinedAt = joinedAt
        self.leftAt = leftAt
    }

    var outcome: TimerOutcome? {
        get { outcomeValue.flatMap { TimerOutcome(rawValue: $0) } }
        set { outcomeValue = newValue?.rawValue }
    }
}
