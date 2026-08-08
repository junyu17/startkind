import Foundation
import SwiftData

/// Sync coding helpers (JSON <-> Swift types) for Supabase interchange.
enum SyncCoding {
    static func date(_ json: [String: Any], _ key: String) -> Date? {
        guard let s = json[key] as? String else { return nil }
        return Self.formatter.date(from: s)
    }
    static func str(_ json: [String: Any], _ key: String) -> String? { json[key] as? String }
    static func uuid(_ json: [String: Any], _ key: String) -> UUID? {
        (json[key] as? String).flatMap { UUID(uuidString: $0) }
    }
    static func int(_ json: [String: Any], _ key: String) -> Int? {
        if let n = json[key] as? Int { return n }
        if let n = json[key] as? NSNumber { return n.intValue }
        return nil
    }
    static func double(_ json: [String: Any], _ key: String) -> Double? {
        if let n = json[key] as? Double { return n }
        if let n = json[key] as? NSNumber { return n.doubleValue }
        return nil
    }
    static func bool(_ json: [String: Any], _ key: String) -> Bool? { json[key] as? Bool }
    static func encode(_ d: Date?) -> Any? { d.map { Self.formatter.string(from: $0) } }
    static func encode(_ s: String?) -> Any? { s }
    static func encode(_ n: Double?) -> Any? { n }

    private static var formatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }
}

// MARK: - UserProfileModel

extension UserProfileModel {
    var syncTable: String { "user_profiles" }
    func syncJSON() -> [String: Any] {
        ["id": id.uuidString, "locale": locale, "timezone": timezone,
         "entitlement_state": entitlementState, "preferred_tone": preferredTone,
         "created_at": SyncCoding.encode(createdAt) as Any, "updated_at": SyncCoding.encode(updatedAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any]) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        self.init(
            id: id,
            locale: SyncCoding.str(json, "locale") ?? "en",
            timezone: SyncCoding.str(json, "timezone") ?? "UTC",
            entitlementState: EntitlementState(rawValue: SyncCoding.str(json, "entitlement_state") ?? "free") ?? .free,
            preferredTone: PreferredTone(rawValue: SyncCoding.str(json, "preferred_tone") ?? "neutral") ?? .neutral,
            createdAt: SyncCoding.date(json, "created_at") ?? .now,
            updatedAt: SyncCoding.date(json, "updated_at") ?? .now
        )
    }
    func applySync(_ json: [String: Any]) {
        locale = SyncCoding.str(json, "locale") ?? locale
        timezone = SyncCoding.str(json, "timezone") ?? timezone
        entitlementState = SyncCoding.str(json, "entitlement_state") ?? entitlementState
        preferredTone = SyncCoding.str(json, "preferred_tone") ?? preferredTone
        if let u = SyncCoding.date(json, "updated_at") { updatedAt = u }
    }
}

// MARK: - CaptureModel

extension CaptureModel {
    var syncTable: String { "captures" }
    func syncJSON(userId: UUID) -> [String: Any] {
        ["id": id.uuidString, "user_id": userId.uuidString, "source_type": sourceType,
         "raw_text": rawText, "language": language, "created_at": SyncCoding.encode(createdAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        self.init(
            id: id, userId: userId,
            source: CaptureSource(rawValue: SyncCoding.str(json, "source_type") ?? "text") ?? .text,
            rawText: SyncCoding.str(json, "raw_text") ?? "",
            language: SyncCoding.str(json, "language") ?? "en",
            createdAt: SyncCoding.date(json, "created_at") ?? .now
        )
    }
}

// MARK: - TaskItemModel

extension TaskItemModel {
    var syncTable: String { "task_items" }
    func syncJSON(userId: UUID) -> [String: Any] {
        ["id": id.uuidString, "user_id": userId.uuidString,
         "capture_id": SyncCoding.encode(captureId?.uuidString) as Any, "title": title,
         "category": categoryValue, "emotional_load": emotionalLoadValue, "status": statusValue,
         "created_at": SyncCoding.encode(createdAt) as Any, "updated_at": SyncCoding.encode(updatedAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        self.init(
            id: id, userId: userId,
            captureId: SyncCoding.uuid(json, "capture_id"),
            title: SyncCoding.str(json, "title") ?? "",
            category: TaskCategory(rawValue: SyncCoding.str(json, "category") ?? "other") ?? .other,
            emotionalLoad: EmotionalLoad(rawValue: SyncCoding.str(json, "emotional_load") ?? "medium") ?? .medium,
            status: TaskStatus(rawValue: SyncCoding.str(json, "status") ?? "active") ?? .active,
            createdAt: SyncCoding.date(json, "created_at") ?? .now,
            updatedAt: SyncCoding.date(json, "updated_at") ?? .now
        )
    }
    func applySync(_ json: [String: Any]) {
        title = SyncCoding.str(json, "title") ?? title
        if let c = SyncCoding.str(json, "category").flatMap(TaskCategory.init(rawValue:)) { category = c }
        if let e = SyncCoding.str(json, "emotional_load").flatMap(EmotionalLoad.init(rawValue:)) { emotionalLoad = e }
        if let s = SyncCoding.str(json, "status").flatMap(TaskStatus.init(rawValue:)) { status = s }
        captureId = SyncCoding.uuid(json, "capture_id")
        if let u = SyncCoding.date(json, "updated_at") { updatedAt = u }
    }
}

// MARK: - NextStepModel

extension NextStepModel {
    var syncTable: String { "next_steps" }
    func syncJSON(userId: UUID) -> [String: Any] {
        ["id": id.uuidString, "task_id": SyncCoding.encode(taskId?.uuidString) as Any, "user_id": userId.uuidString,
         "title": title, "step_text": stepText, "stop_condition": stopCondition,
         "category": categoryValue, "shrink_level": shrinkLevelValue,
         "estimated_minutes": estimatedMinutes, "target_minutes": targetMinutes,
         "status": statusValue, "generated_by": generatedByValue, "why_this_step": SyncCoding.encode(whyThisStep) as Any,
         "created_at": SyncCoding.encode(createdAt) as Any, "started_at": SyncCoding.encode(startedAt) as Any,
         "completed_at": SyncCoding.encode(completedAt) as Any, "updated_at": SyncCoding.encode(updatedAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        let proposal = NextStepProposal(
            id: id,
            title: SyncCoding.str(json, "title") ?? "",
            step: SyncCoding.str(json, "step_text") ?? "",
            timerMinutes: SyncCoding.int(json, "target_minutes") ?? 10,
            stopCondition: SyncCoding.str(json, "stop_condition") ?? "",
            category: TaskCategory(rawValue: SyncCoding.str(json, "category") ?? "other") ?? .other,
            shrinkLevel: ShrinkLevel(rawValue: SyncCoding.int(json, "shrink_level") ?? 0) ?? .zero,
            generatedBy: NextStepGeneratedBy(rawValue: SyncCoding.str(json, "generated_by") ?? "local_template") ?? .localTemplate,
            whyThisStep: SyncCoding.str(json, "why_this_step")
        )
        self.init(
            id: id, taskId: SyncCoding.uuid(json, "task_id"), userId: userId,
            proposal: proposal,
            status: NextStepStatus(rawValue: SyncCoding.str(json, "status") ?? "suggested") ?? .suggested,
            createdAt: SyncCoding.date(json, "created_at") ?? .now,
            startedAt: SyncCoding.date(json, "started_at"),
            completedAt: SyncCoding.date(json, "completed_at"),
            updatedAt: SyncCoding.date(json, "updated_at")
        )
    }
    func applySync(_ json: [String: Any]) {
        title = SyncCoding.str(json, "title") ?? title
        stepText = SyncCoding.str(json, "step_text") ?? stepText
        stopCondition = SyncCoding.str(json, "stop_condition") ?? stopCondition
        if let c = SyncCoding.str(json, "category").flatMap(TaskCategory.init(rawValue:)) { category = c }
        if let s = SyncCoding.int(json, "shrink_level").flatMap(ShrinkLevel.init(rawValue:)) { shrinkLevel = s }
        if let v = SyncCoding.int(json, "estimated_minutes") { estimatedMinutes = v }
        if let v = SyncCoding.int(json, "target_minutes") { targetMinutes = v }
        if let s = SyncCoding.str(json, "status").flatMap(NextStepStatus.init(rawValue:)) { status = s }
        if let g = SyncCoding.str(json, "generated_by").flatMap(NextStepGeneratedBy.init(rawValue:)) { generatedBy = g }
        whyThisStep = SyncCoding.str(json, "why_this_step")
        taskId = SyncCoding.uuid(json, "task_id")
        startedAt = SyncCoding.date(json, "started_at")
        completedAt = SyncCoding.date(json, "completed_at")
        if let u = SyncCoding.date(json, "updated_at") { updatedAt = u }
    }
}

// MARK: - TimerSessionModel

extension TimerSessionModel {
    var syncTable: String { "timer_sessions" }
    func syncJSON(userId: UUID) -> [String: Any] {
        ["id": id.uuidString, "next_step_id": SyncCoding.encode(nextStepId?.uuidString) as Any, "user_id": userId.uuidString,
         "planned_minutes": plannedMinutes, "actual_seconds": actualSeconds,
         "outcome": outcomeValue, "co_start_mode": coStartModeValue,
         "category": categoryValue, "estimated_minutes": estimatedMinutes,
         "created_at": SyncCoding.encode(createdAt) as Any, "ended_at": SyncCoding.encode(endedAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        self.init(
            id: id, nextStepId: SyncCoding.uuid(json, "next_step_id"), userId: userId,
            plannedMinutes: SyncCoding.int(json, "planned_minutes") ?? 10,
            actualSeconds: SyncCoding.int(json, "actual_seconds") ?? 0,
            outcome: TimerOutcome(rawValue: SyncCoding.str(json, "outcome") ?? "paused") ?? .paused,
            coStartMode: CoStartMode(rawValue: SyncCoding.str(json, "co_start_mode") ?? "none") ?? .none,
            category: TaskCategory(rawValue: SyncCoding.str(json, "category") ?? "other") ?? .other,
            estimatedMinutes: SyncCoding.int(json, "estimated_minutes") ?? 10,
            createdAt: SyncCoding.date(json, "created_at") ?? .now,
            endedAt: SyncCoding.date(json, "ended_at")
        )
    }
}

// MARK: - TimeCalibrationProfileModel

extension TimeCalibrationProfileModel {
    var syncTable: String { "time_calibration_profiles" }
    func syncJSON(userId: UUID) -> [String: Any] {
        ["id": id.uuidString, "user_id": userId.uuidString, "category": categoryValue,
         "estimate_multiplier": estimateMultiplier,
         "median_actual_minutes": SyncCoding.encode(medianActualMinutes) as Any,
         "completion_rate": completionRate, "best_start_window": SyncCoding.encode(bestStartWindow) as Any,
         "sample_count": sampleCount, "updated_at": SyncCoding.encode(updatedAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        self.init(
            id: id, userId: userId,
            category: TaskCategory(rawValue: SyncCoding.str(json, "category") ?? "other") ?? .other,
            estimateMultiplier: SyncCoding.double(json, "estimate_multiplier") ?? 1.0,
            medianActualMinutes: SyncCoding.double(json, "median_actual_minutes"),
            completionRate: SyncCoding.double(json, "completion_rate") ?? 0,
            bestStartWindow: SyncCoding.str(json, "best_start_window"),
            sampleCount: SyncCoding.int(json, "sample_count") ?? 0,
            updatedAt: SyncCoding.date(json, "updated_at") ?? .now
        )
    }
    func applySync(_ json: [String: Any]) {
        estimateMultiplier = SyncCoding.double(json, "estimate_multiplier") ?? estimateMultiplier
        medianActualMinutes = SyncCoding.double(json, "median_actual_minutes")
        completionRate = SyncCoding.double(json, "completion_rate") ?? completionRate
        bestStartWindow = SyncCoding.str(json, "best_start_window")
        if let v = SyncCoding.int(json, "sample_count") { sampleCount = v }
        if let u = SyncCoding.date(json, "updated_at") { updatedAt = u }
    }
}

// MARK: - RecoveryCapsuleModel

extension RecoveryCapsuleModel {
    var syncTable: String { "recovery_capsules" }
    func syncJSON(userId: UUID) -> [String: Any] {
        ["id": id.uuidString, "user_id": userId.uuidString,
         "task_id": SyncCoding.encode(taskId?.uuidString) as Any, "last_step_id": SyncCoding.encode(lastStepId?.uuidString) as Any,
         "state_summary": stateSummary, "resume_step_text": resumeStepText, "resume_title": resumeTitle,
         "resume_stop_condition": resumeStopCondition, "resume_timer_minutes": resumeTimerMinutes,
         "resume_category": resumeCategoryValue, "related_link": SyncCoding.encode(relatedLink) as Any,
         "related_draft": SyncCoding.encode(relatedDraft) as Any, "active": active,
         "created_at": SyncCoding.encode(createdAt) as Any, "updated_at": SyncCoding.encode(updatedAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        self.init(
            id: id, userId: userId, taskId: SyncCoding.uuid(json, "task_id"), lastStepId: SyncCoding.uuid(json, "last_step_id"),
            stateSummary: SyncCoding.str(json, "state_summary") ?? "",
            resumeStepText: SyncCoding.str(json, "resume_step_text") ?? "",
            resumeTitle: SyncCoding.str(json, "resume_title") ?? "",
            resumeStopCondition: SyncCoding.str(json, "resume_stop_condition") ?? "",
            resumeTimerMinutes: SyncCoding.int(json, "resume_timer_minutes") ?? 10,
            resumeCategory: TaskCategory(rawValue: SyncCoding.str(json, "resume_category") ?? "other") ?? .other,
            relatedLink: SyncCoding.str(json, "related_link"), relatedDraft: SyncCoding.str(json, "related_draft"),
            active: SyncCoding.bool(json, "active") ?? true,
            createdAt: SyncCoding.date(json, "created_at") ?? .now, updatedAt: SyncCoding.date(json, "updated_at") ?? .now
        )
    }
    func applySync(_ json: [String: Any]) {
        stateSummary = SyncCoding.str(json, "state_summary") ?? stateSummary
        resumeStepText = SyncCoding.str(json, "resume_step_text") ?? resumeStepText
        resumeTitle = SyncCoding.str(json, "resume_title") ?? resumeTitle
        resumeStopCondition = SyncCoding.str(json, "resume_stop_condition") ?? resumeStopCondition
        if let v = SyncCoding.int(json, "resume_timer_minutes") { resumeTimerMinutes = v }
        if let c = SyncCoding.str(json, "resume_category").flatMap(TaskCategory.init(rawValue:)) { resumeCategory = c }
        relatedLink = SyncCoding.str(json, "related_link")
        relatedDraft = SyncCoding.str(json, "related_draft")
        active = SyncCoding.bool(json, "active") ?? active
        taskId = SyncCoding.uuid(json, "task_id")
        lastStepId = SyncCoding.uuid(json, "last_step_id")
        if let u = SyncCoding.date(json, "updated_at") { updatedAt = u }
    }
}

// MARK: - AdminArtifactModel

extension AdminArtifactModel {
    var syncTable: String { "admin_artifacts" }
    func syncJSON(userId: UUID) -> [String: Any] {
        let oneNextStep: [String: Any] = [
            "title": oneNextStepTitle, "step": oneNextStepText,
            "stop_condition": oneNextStepStop, "timer_minutes": oneNextStepTimer
        ]
        return ["id": id.uuidString, "user_id": userId.uuidString,
                "task_id": SyncCoding.encode(taskId?.uuidString) as Any, "artifact_type": artifactTypeValue,
                "extracted_due_date": SyncCoding.encode(extractedDueDate) as Any,
                "extracted_amount": SyncCoding.encode(extractedAmount) as Any,
                "extracted_contact": SyncCoding.encode(extractedContact) as Any,
                "extracted_url": SyncCoding.encode(extractedURL) as Any,
                "required_documents": requiredDocuments,
                "one_next_step": oneNextStep,
                "confidence": confidence, "created_at": SyncCoding.encode(createdAt) as Any]
    }
    convenience init?(syncJSON json: [String: Any], userId: UUID) {
        guard let id = SyncCoding.uuid(json, "id") else { return nil }
        let oneNext = (json["one_next_step"] as? [String: Any]) ?? [:]
        let proposal = NextStepProposal(
            title: SyncCoding.str(oneNext, "title") ?? "",
            step: SyncCoding.str(oneNext, "step") ?? "",
            timerMinutes: SyncCoding.int(oneNext, "timer_minutes") ?? 5,
            stopCondition: SyncCoding.str(oneNext, "stop_condition") ?? "",
            category: .other, shrinkLevel: .one, generatedBy: .cloudAI
        )
        let result = AdminParseResult(
            artifactType: AdminArtifactType(rawValue: SyncCoding.str(json, "artifact_type") ?? "other") ?? .other,
            dueDate: SyncCoding.date(json, "extracted_due_date"),
            amount: SyncCoding.str(json, "extracted_amount"),
            contact: SyncCoding.str(json, "extracted_contact"),
            linkOrPhone: SyncCoding.str(json, "extracted_url"),
            requiredDocuments: (json["required_documents"] as? [String]) ?? [],
            oneNextStep: proposal,
            confidence: SyncCoding.double(json, "confidence") ?? 0.5,
            missingInfo: []
        )
        self.init(id: id, userId: userId, taskId: SyncCoding.uuid(json, "task_id"), result: result,
                  createdAt: SyncCoding.date(json, "created_at") ?? .now)
    }
}
