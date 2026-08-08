import Foundation

// MARK: - Task Category

/// Stable internal category IDs. Mirrors `docs/DATA_MODEL.md`.
enum TaskCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case bills, email, appointments, returns, insurance, banking, taxes
    case household, familyAdmin = "family_admin", medical, workAdmin = "work_admin"
    case school, cleaning, errands, other

    var id: String { rawValue }

    /// The localization key, e.g. "category.bills".
    var localizationKey: String { "category.\(rawValue)" }

    var displayName: String { NSLocalizedString(localizationKey, comment: "task category") }

    var systemImage: String {
        switch self {
        case .bills: return "doc.text.fill"
        case .email: return "envelope.fill"
        case .appointments: return "calendar"
        case .returns: return "arrow.uturn.left.circle.fill"
        case .insurance: return "shield.fill"
        case .banking: return "banknote.fill"
        case .taxes: return "percent"
        case .household: return "house.fill"
        case .familyAdmin: return "person.2.fill"
        case .medical: return "cross.case.fill"
        case .workAdmin: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        case .cleaning: return "sparkles"
        case .errands: return "bag.fill"
        case .other: return "circle.fill"
        }
    }

    /// Default estimate (minutes) used before any personal calibration.
    var defaultEstimateMinutes: Int {
        switch self {
        case .bills, .banking, .taxes, .insurance: return 12
        case .email, .workAdmin: return 10
        case .appointments, .medical: return 10
        case .returns, .errands: return 10
        case .household, .cleaning: return 12
        case .familyAdmin, .school: return 12
        case .other: return 10
        }
    }
}

// MARK: - Entitlement

/// Mirrors `docs/TECHNICAL_ARCHITECTURE.md` entitlement states.
enum EntitlementState: String, Codable, CaseIterable, Sendable {
    case free, plusTrial = "plus_trial", plusActive = "plus_active"
    case plusGracePeriod = "plus_grace_period", plusExpired = "plus_expired"

    var isPlus: Bool {
        switch self {
        case .plusTrial, .plusActive, .plusGracePeriod: return true
        case .free, .plusExpired: return false
        }
    }

    var displayName: String {
        switch self {
        case .free: return NSLocalizedString("settings.subscription.free", comment: "")
        default: return NSLocalizedString("settings.subscription.plus", comment: "")
        }
    }
}

// MARK: - Capture

enum CaptureSource: String, Codable, CaseIterable, Sendable {
    case voice, text, screenshot, photo, email, calendar, manual
}

// MARK: - Emotional Load

enum EmotionalLoad: String, Codable, CaseIterable, Sendable {
    case low, medium, high
}

enum PreferredTone: String, Codable, CaseIterable, Sendable {
    case neutral, warm, direct
}

// MARK: - Task Status

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case active, completed, paused, deferred, archived
}

// MARK: - Next Step

enum NextStepStatus: String, Codable, CaseIterable, Sendable {
    case suggested, started, completed, skipped, paused
}

enum NextStepGeneratedBy: String, Codable, CaseIterable, Sendable {
    case localTemplate = "local_template"
    case cloudAI = "cloud_ai"
    case user
}

// MARK: - Timer

enum TimerOutcome: String, Codable, CaseIterable, Sendable {
    case completed, partial, paused, abandoned
}

enum CoStartMode: String, Codable, CaseIterable, Sendable {
    case none, ai, friend, quietRoom = "quiet_room"
}

// MARK: - Co-Start Room

enum CoStartRoomType: String, Codable, CaseIterable, Sendable {
    case friendLink = "friend_link"
    case aiQuiet = "ai_quiet"
    case quietRoom = "quiet_room"
}

enum CoStartRoomStatus: String, Codable, CaseIterable, Sendable {
    case scheduled, active, ended, cancelled
}

// MARK: - Admin Artifact

enum AdminArtifactType: String, Codable, CaseIterable, Sendable {
    case bill, email, appointment, `return`, insurance, banking
    case school, household, medical, other
}
