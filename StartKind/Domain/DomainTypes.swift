import Foundation

/// Shrink level per `docs/AI_BEHAVIOR_SPEC.md`.
/// 0 = useful step (10–15m), 1 = smaller (5–10m), 2 = tiny (2–5m), 3 = friction-only (<2m).
enum ShrinkLevel: Int, Codable, CaseIterable, Sendable, Comparable {
    case zero = 0, one = 1, two = 2, three = 3

    var targetMinutes: Int {
        switch self {
        case .zero: return 12
        case .one: return 7
        case .two: return 4
        case .three: return 1
        }
    }

    /// Allowed timer presets for this shrink level.
    var allowedTimers: [Int] {
        switch self {
        case .zero: return [10, 15, 25]
        case .one: return [5, 10, 15]
        case .two: return [5, 10]
        case .three: return [5]
        }
    }

    static func < (lhs: ShrinkLevel, rhs: ShrinkLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A concrete, startable next step produced by the engine.
/// Pure value type — no persistence dependency, fully unit-testable.
struct NextStepProposal: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var title: String
    var step: String
    var timerMinutes: Int
    var stopCondition: String
    var category: TaskCategory
    var shrinkLevel: ShrinkLevel
    var generatedBy: NextStepGeneratedBy
    var whyThisStep: String?

    init(
        id: UUID = UUID(),
        title: String,
        step: String,
        timerMinutes: Int,
        stopCondition: String,
        category: TaskCategory,
        shrinkLevel: ShrinkLevel = .zero,
        generatedBy: NextStepGeneratedBy = .localTemplate,
        whyThisStep: String? = nil
    ) {
        self.id = id
        self.title = title
        self.step = step
        self.timerMinutes = timerMinutes
        self.stopCondition = stopCondition
        self.category = category
        self.shrinkLevel = shrinkLevel
        self.generatedBy = generatedBy
        self.whyThisStep = whyThisStep
    }
}

/// Result of the Admin Task Reader (Plus). Matches the system prompt JSON shape.
struct AdminParseResult: Equatable, Sendable, Codable {
    var artifactType: AdminArtifactType
    var dueDate: Date?
    var amount: String?
    var contact: String?
    var linkOrPhone: String?
    var requiredDocuments: [String]
    var oneNextStep: NextStepProposal
    var confidence: Double // 0...1
    var missingInfo: [String]

    init(
        artifactType: AdminArtifactType,
        dueDate: Date? = nil,
        amount: String? = nil,
        contact: String? = nil,
        linkOrPhone: String? = nil,
        requiredDocuments: [String] = [],
        oneNextStep: NextStepProposal,
        confidence: Double = 0.5,
        missingInfo: [String] = []
    ) {
        self.artifactType = artifactType
        self.dueDate = dueDate
        self.amount = amount
        self.contact = contact
        self.linkOrPhone = linkOrPhone
        self.requiredDocuments = requiredDocuments
        self.oneNextStep = oneNextStep
        self.confidence = confidence
        self.missingInfo = missingInfo
    }
}

/// Snapshot of one category's calibration, used by Patterns UI.
struct CalibrationSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: TaskCategory
    let estimateMultiplier: Double
    let medianActualMinutes: Double?
    let completionRate: Double // 0...1
    let bestStartWindow: String?
    let sampleCount: Int

    init(
        id: UUID = UUID(),
        category: TaskCategory,
        estimateMultiplier: Double,
        medianActualMinutes: Double?,
        completionRate: Double,
        bestStartWindow: String?,
        sampleCount: Int
    ) {
        self.id = id
        self.category = category
        self.estimateMultiplier = estimateMultiplier
        self.medianActualMinutes = medianActualMinutes
        self.completionRate = completionRate
        self.bestStartWindow = bestStartWindow
        self.sampleCount = sampleCount
    }
}

/// Daily free usage state.
struct UsageState: Equatable, Sendable, Codable {
    var stepsUsedToday: Int
    var stepsLimit: Int
    var adminQuickStartsUsedToday: Int
    var adminQuickStartLimit: Int
    var resetsAt: Date

    var stepsRemaining: Int { max(0, stepsLimit - stepsUsedToday) }
    var adminQuickStartsRemaining: Int { max(0, adminQuickStartLimit - adminQuickStartsUsedToday) }
    var canGenerateStep: Bool { stepsRemaining > 0 }
    var canUseAdminQuickStart: Bool { adminQuickStartsRemaining > 0 }
}

/// What kind of capture input the engine received.
struct CaptureInput: Equatable, Sendable {
    var rawText: String
    var source: CaptureSource
    var preferredCategory: TaskCategory?
    var language: String // "en" or "zh-Hans"
}
