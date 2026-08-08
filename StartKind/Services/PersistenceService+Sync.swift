import Foundation
import SwiftData

/// Mutable entities participate in last-write-wins merge on `updated_at`.
protocol SyncableMutable: PersistentModel {
    var syncID: UUID { get }
    var syncUpdatedAt: Date { get }
    func applySync(_ json: [String: Any])
}
/// Immutable entities are insert-only by id (history records).
protocol SyncableImmutable: PersistentModel {
    var syncID: UUID { get }
}

extension UserProfileModel: SyncableMutable { var syncID: UUID { id }; var syncUpdatedAt: Date { updatedAt } }
extension TaskItemModel: SyncableMutable { var syncID: UUID { id }; var syncUpdatedAt: Date { updatedAt } }
extension TimeCalibrationProfileModel: SyncableMutable { var syncID: UUID { id }; var syncUpdatedAt: Date { updatedAt } }
extension RecoveryCapsuleModel: SyncableMutable { var syncID: UUID { id }; var syncUpdatedAt: Date { updatedAt } }
extension CaptureModel: SyncableImmutable { var syncID: UUID { id } }
extension NextStepModel: SyncableMutable { var syncID: UUID { id }; var syncUpdatedAt: Date { updatedAt ?? createdAt } }
extension TimerSessionModel: SyncableImmutable { var syncID: UUID { id } }
extension AdminArtifactModel: SyncableImmutable { var syncID: UUID { id } }

extension PersistenceService {
    /// Tables synced (user_profiles is handled specially due to id = auth user id).
    static let syncTables = ["user_profiles", "captures", "task_items", "next_steps",
                             "timer_sessions", "time_calibration_profiles", "recovery_capsules", "admin_artifacts"]

    /// Export all local data per table for push. `authUserId` is the Supabase user id
    /// (used as user_profiles.id and the user_id column on other tables).
    func syncExport(authUserId: UUID) -> [String: [[String: Any]]] {
        var out: [String: [[String: Any]]] = [:]
        let p = ensureProfile()
        out["user_profiles"] = [[
            "id": authUserId.uuidString,
            "locale": p.locale, "timezone": p.timezone,
            "entitlement_state": p.entitlementState, "preferred_tone": p.preferredTone,
            "created_at": SyncCoding.encode(p.createdAt) as Any,
            "updated_at": SyncCoding.encode(p.updatedAt) as Any
        ]]
        out["captures"] = ((try? context.fetch(FetchDescriptor<CaptureModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        out["task_items"] = ((try? context.fetch(FetchDescriptor<TaskItemModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        out["next_steps"] = ((try? context.fetch(FetchDescriptor<NextStepModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        out["timer_sessions"] = ((try? context.fetch(FetchDescriptor<TimerSessionModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        out["time_calibration_profiles"] = ((try? context.fetch(FetchDescriptor<TimeCalibrationProfileModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        out["recovery_capsules"] = ((try? context.fetch(FetchDescriptor<RecoveryCapsuleModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        out["admin_artifacts"] = ((try? context.fetch(FetchDescriptor<AdminArtifactModel>())) ?? []).map { $0.syncJSON(userId: authUserId) }
        return out
    }

    /// Merge remote data into local. user_profiles: sync preferences (locale/timezone/tone)
    /// via LWW only - entitlement is owned by StoreKit/verify_receipt, not user_profiles sync.
    func syncImport(_ remote: [String: [[String: Any]]]) {
        let localUserId = ensureProfile().id
        if let row = remote["user_profiles"]?.first {
            let p = ensureProfile()
            let remoteUpdated = SyncCoding.date(row, "updated_at") ?? .distantPast
            if remoteUpdated > p.updatedAt {
                p.locale = SyncCoding.str(row, "locale") ?? p.locale
                p.timezone = SyncCoding.str(row, "timezone") ?? p.timezone
                p.preferredTone = SyncCoding.str(row, "preferred_tone") ?? p.preferredTone
                p.updatedAt = remoteUpdated
            }
        }
        mergeMutable(remote["task_items"] ?? []) { TaskItemModel(syncJSON: $0, userId: localUserId) }
        mergeMutable(remote["time_calibration_profiles"] ?? []) { TimeCalibrationProfileModel(syncJSON: $0, userId: localUserId) }
        mergeMutable(remote["recovery_capsules"] ?? []) { RecoveryCapsuleModel(syncJSON: $0, userId: localUserId) }
        mergeImmutable(remote["captures"] ?? []) { CaptureModel(syncJSON: $0, userId: localUserId) }
        mergeMutable(remote["next_steps"] ?? []) { NextStepModel(syncJSON: $0, userId: localUserId) }
        mergeImmutable(remote["timer_sessions"] ?? []) { TimerSessionModel(syncJSON: $0, userId: localUserId) }
        mergeImmutable(remote["admin_artifacts"] ?? []) { AdminArtifactModel(syncJSON: $0, userId: localUserId) }
        try? context.save()
    }

    private func mergeMutable<T: SyncableMutable>(_ rows: [[String: Any]], make: ([String: Any]) -> T?) {
        let existing = ((try? context.fetch(FetchDescriptor<T>())) ?? []).reduce(into: [UUID: T]()) { $0[$1.syncID] = $1 }
        for row in rows {
            guard let id = SyncCoding.uuid(row, "id") else { continue }
            if let local = existing[id] {
                let remoteUpdated = SyncCoding.date(row, "updated_at") ?? .distantPast
                if remoteUpdated > local.syncUpdatedAt { local.applySync(row) }
            } else if let new = make(row) {
                context.insert(new)
            }
        }
    }

    private func mergeImmutable<T: SyncableImmutable>(_ rows: [[String: Any]], make: ([String: Any]) -> T?) {
        let existingIDs = Set(((try? context.fetch(FetchDescriptor<T>())) ?? []).map { $0.syncID })
        for row in rows {
            guard let id = SyncCoding.uuid(row, "id"), !existingIDs.contains(id) else { continue }
            if let new = make(row) { context.insert(new) }
        }
    }
}
