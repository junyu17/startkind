import Foundation
import Combine

enum UsageError: LocalizedError {
    case stepLimitReached, adminLimitReached

    var errorDescription: String? {
        switch self {
        case .stepLimitReached: return "Today's free steps are used up."
        case .adminLimitReached: return "Today's free Admin Quick Start is used up."
        }
    }
}

enum AuthError: LocalizedError {
    case notConfigured, invalidCredentials, network

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Cloud sign-in isn't configured."
        case .invalidCredentials: return "Sign-in failed. Check your email and password."
        case .network: return "Couldn't reach the server. Try again."
        }
    }
}

/// The composition root. Holds all services and domain components, and exposes
/// the high-level actions the UI drives. All access is main-actor bound.
@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceService
    let entitlement: EntitlementService
    let usage: UsageTracker
    let speech: SpeechService
    let ai: AIClient
    let sync: SyncService
    let supabase: SupabaseClient?
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var hasStarted: Bool

    let engine: NextStepEngine
    let shrinker: TaskShrinker
    let rescheduler: Rescheduler
    let calibrator: TimeCalibrator

    private var cancellables = Set<AnyCancellable>()

    init(inMemory: Bool = false) {
        let persistence: PersistenceService
        do {
            persistence = try PersistenceService(inMemory: inMemory)
        } catch {
            fatalError("StartKind storage could not be initialized: \(error)")
        }
        self.persistence = persistence
        self.entitlement = EntitlementService()
        self.usage = UsageTracker()
        self.speech = SpeechService()
        let supabase: SupabaseClient? = {
            if let endpoint = SupabaseConfig.endpoint, let anonKey = SupabaseConfig.anonKey {
                return SupabaseClient(endpoint: endpoint, anonKey: anonKey)
            }
            return nil
        }()
        self.supabase = supabase
        self.ai = CloudAIClient(supabase: supabase)
        self.sync = SupabaseSync(supabase: supabase)
        self.engine = NextStepEngine()
        self.shrinker = TaskShrinker()
        self.rescheduler = Rescheduler()
        self.calibrator = TimeCalibrator()
        let launchArgs = ProcessInfo.processInfo.arguments
        self.hasStarted = launchArgs.contains("-UITEST")
            || (!launchArgs.contains("-UITEST_AUTH") && UserDefaults.standard.bool(forKey: "sk_has_started"))

        // Keep the persisted profile entitlement in sync with StoreKit.
        entitlement.$state
            .removeDuplicates()
            .sink { [weak self, weak persistence] state in
                persistence?.updateProfile(entitlement: state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Launch

    func bootstrap() async {
        let args = ProcessInfo.processInfo.arguments
        let skipStoreKit = args.contains("-UITEST") || args.contains("-UITEST_AUTH")
        LocalizationManager.shared.setLanguage(persistence.profile?.locale ?? "en")
        isSignedIn = supabase?.isAuthenticated ?? false
        if !skipStoreKit {
            await entitlement.load()
        }
        speech.refreshAuthorizationState()
        if !skipStoreKit {
            persistence.updateProfile(entitlement: entitlement.state)
        }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        guard let supabase else { throw AuthError.notConfigured }
        do {
            try await supabase.signIn(email: email, password: password)
        } catch let SupabaseError.http(code, _) where code == 400 || code == 401 {
            throw AuthError.invalidCredentials
        } catch is SupabaseError {
            throw AuthError.network
        }
        isSignedIn = true
        markStarted()
        Task { await runSync() }
    }

    func signUp(email: String, password: String) async throws {
        guard let supabase else { throw AuthError.notConfigured }
        do {
            try await supabase.signUp(email: email, password: password)
        } catch let SupabaseError.http(code, _) where code == 400 || code == 422 {
            throw AuthError.invalidCredentials
        } catch is SupabaseError {
            throw AuthError.network
        }
        isSignedIn = supabase.isAuthenticated
        markStarted()
        Task { await runSync() }
    }

    /// Skip cloud sign-in and use the app locally (Free, no account).
    func skipAuth() {
        isSignedIn = false
        markStarted()
    }

    func signOut() {
        supabase?.signOut()
        isSignedIn = false
    }

    /// Return to the sign-in screen (e.g. user chose to sign in from Settings).
    func resetToAuth() {
        hasStarted = false
        UserDefaults.standard.set(false, forKey: "sk_has_started")
    }

    // MARK: - Entitlement sync

    /// Send the App Store receipt to the backend for server-side verification,
    /// mirroring the Plus entitlement into the `entitlements` table (the
    /// cross-device source of truth the Edge Functions check).
    func syncEntitlementToBackend() async {
        guard let supabase, supabase.isAuthenticated else { return }
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let data = try? Data(contentsOf: receiptURL) else { return }
        let receipt = data.base64EncodedString()
        _ = try? await supabase.invokeFunction("verify_receipt", body: ["receipt": receipt])
    }

    // MARK: - Co-Start

    @discardableResult
    private func createCoStartRoom(type: CoStartRoomType, stepText: String) -> CoStartRoomModel {
        let hostId = persistence.userId
        let room = CoStartRoomModel(hostUserId: hostId, roomType: type, durationMinutes: 25, status: .active, startsAt: .now)
        persistence.context.insert(room)
        let me = CoStartParticipantModel(roomId: room.id, userId: hostId, displayName: L("costart.you"), statedStep: stepText)
        persistence.context.insert(me)
        if type == .aiQuiet {
            let ai = CoStartParticipantModel(roomId: room.id, userId: nil, displayName: L("costart.ai"), statedStep: L("costart.aiQuietPresence"))
            persistence.context.insert(ai)
        }
        try? persistence.context.save()
        return room
    }

    /// Start a co-start room + a 25-min timer session for the given step.
    @discardableResult
    func startCoStart(type: CoStartRoomType, step: NextStepModel, stepText: String) -> (room: CoStartRoomModel, session: TimerSessionModel) {
        let room = createCoStartRoom(type: type, stepText: stepText)
        let coStart: CoStartMode = (type == .aiQuiet) ? .ai : .friend
        let session = persistence.startTimer(for: step, plannedMinutes: 25, coStart: coStart)
        if type == .friendLink {
            Task { await publishCoStartRoom(room: room, stepText: stepText) }
        }
        return (room, session)
    }

    func endCoStart(room: CoStartRoomModel, session: TimerSessionModel, outcome: TimerOutcome, step: NextStepModel?) {
        room.status = .ended
        room.endedAt = .now
        let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
        persistence.recordTimerOutcome(session: session, actualSeconds: elapsed, outcome: outcome, step: step, isPlus: isPlus)
        try? persistence.context.save()
    }

    /// Invite link for a friend co-start room (deep link with room id).
    func inviteLink(for room: CoStartRoomModel) -> URL? {
        var components = URLComponents(string: "startkind://join")
        components?.queryItems = [URLQueryItem(name: "room", value: room.id.uuidString)]
        return components?.url
    }

    private func publishCoStartRoom(room: CoStartRoomModel, stepText: String) async {
        guard let supabase else { return }
        if !supabase.isAuthenticated {
            try? await supabase.anonymousSignIn()
            isSignedIn = supabase.isAuthenticated
        }
        guard supabase.isAuthenticated,
              let userIdString = try? await supabase.getCurrentUserId() else { return }
        try? await supabase.upsert(table: "co_start_rooms", rows: [[
            "id": room.id.uuidString,
            "host_user_id": userIdString,
            "room_type": room.roomType.rawValue,
            "duration_minutes": room.durationMinutes,
            "status": room.status.rawValue,
            "invite_token_hash": SyncCoding.encode(room.inviteTokenHash) as Any,
            "created_at": SyncCoding.encode(room.createdAt) as Any,
            "starts_at": SyncCoding.encode(room.startsAt) as Any,
            "ended_at": SyncCoding.encode(room.endedAt) as Any
        ]])
        try? await supabase.upsert(table: "co_start_participants", rows: [[
            "id": UUID().uuidString,
            "room_id": room.id.uuidString,
            "user_id": userIdString,
            "display_name": L("costart.you"),
            "stated_step": stepText,
            "joined_at": SyncCoding.encode(Date()) as Any
        ]])
    }

    // MARK: - Co-Start guest join

    /// Set by an incoming join deep link; the UI presents the guest join flow.
    @Published var pendingJoinRoomId: UUID?

    func handleJoinURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let roomIdString = components.queryItems?.first(where: { $0.name == "room" })?.value,
              let roomId = UUID(uuidString: roomIdString) else { return }
        pendingJoinRoomId = roomId
    }

    /// Join a co-start room as a guest (anonymous auth, no account required).
    func joinCoStartRoom(roomId: UUID, stepText: String, displayName: String) async throws -> CoStartRoomModel? {
        guard let supabase else { return nil }
        if !supabase.isAuthenticated {
            try await supabase.anonymousSignIn()
            isSignedIn = supabase.isAuthenticated
        }
        guard let userIdString = try? await supabase.getCurrentUserId() else { return nil }
        try await supabase.upsert(table: "co_start_participants", rows: [[
            "id": UUID().uuidString,
            "room_id": roomId.uuidString,
            "user_id": userIdString,
            "display_name": displayName,
            "stated_step": stepText,
            "joined_at": SyncCoding.encode(Date()) as Any
        ]])
        let rooms = (try? await supabase.fetch(table: "co_start_rooms", query: ["id": "eq.\(roomId.uuidString)"])) ?? []
        guard let row = rooms.first else { return nil }
        let room = CoStartRoomModel(
            id: roomId,
            hostUserId: SyncCoding.uuid(row, "host_user_id") ?? UUID(),
            roomType: CoStartRoomType(rawValue: SyncCoding.str(row, "room_type") ?? "quiet_room") ?? .quietRoom,
            durationMinutes: SyncCoding.int(row, "duration_minutes") ?? 25,
            status: CoStartRoomStatus(rawValue: SyncCoding.str(row, "status") ?? "active") ?? .active,
            startsAt: SyncCoding.date(row, "starts_at")
        )
        persistence.context.insert(room)
        try? persistence.context.save()
        return room
    }

    struct CoStartParticipantInfo: Identifiable, Sendable {
        let id: String
        let displayName: String
        let statedStep: String
        let outcome: String?
    }

    /// Poll room participants (near-real-time via periodic polling).
    func fetchCoStartParticipants(roomId: UUID) async -> [CoStartParticipantInfo] {
        guard let supabase, supabase.isAuthenticated else { return [] }
        let rows = (try? await supabase.fetch(table: "co_start_participants", query: ["room_id": "eq.\(roomId.uuidString)"])) ?? []
        return rows.compactMap { row in
            guard let name = row["display_name"] as? String else { return nil }
            return CoStartParticipantInfo(
                id: (row["id"] as? String) ?? UUID().uuidString,
                displayName: name,
                statedStep: (row["stated_step"] as? String) ?? "",
                outcome: row["outcome"] as? String
            )
        }
    }

    /// Guest ends: update own participant outcome.
    func endCoStartGuest(roomId: UUID, outcome: TimerOutcome) async {
        guard let supabase, supabase.isAuthenticated,
              let userIdString = try? await supabase.getCurrentUserId() else { return }
        try? await supabase.patch(
            table: "co_start_participants",
            query: ["room_id": "eq.\(roomId.uuidString)", "user_id": "eq.\(userIdString)"],
            values: ["outcome": outcome.rawValue, "left_at": SyncCoding.encode(Date()) as Any]
        )
    }

    // MARK: - Sync

    /// Full bidirectional sync (push local -> upsert, pull remote -> merge LWW).
    /// Non-fatal: on failure the app continues on local data.
    func runSync() async {
        guard let supabase, supabase.isAuthenticated else { return }
        guard let idString = try? await supabase.getCurrentUserId(),
              let authUserId = UUID(uuidString: idString) else { return }
        let export = persistence.syncExport(authUserId: authUserId)
        do {
            let remote = try await sync.syncAll(export: export, tables: PersistenceService.syncTables)
            persistence.syncImport(remote)
        } catch {
            // Sync failure is non-fatal; app stays usable on local data.
        }
    }

    private func markStarted() {
        hasStarted = true
        UserDefaults.standard.set(true, forKey: "sk_has_started")
    }

    // MARK: - Language

    var currentLanguage: String { persistence.profile?.locale ?? "en" }
    var isPlus: Bool { entitlement.state.isPlus }
    var currentLocale: Locale {
        Locale(identifier: currentLanguage.lowercased().hasPrefix("zh") ? "zh-Hans" : "en")
    }

    func setLanguage(_ language: String) {
        persistence.updateProfile(locale: language)
        LocalizationManager.shared.setLanguage(language)
        objectWillChange.send()
    }

    func setTone(_ tone: PreferredTone) {
        persistence.updateProfile(tone: tone)
    }

    // MARK: - Capture & Next Step

    private var isUITestMode: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-UITEST") || args.contains("-UITEST_AUTH")
    }

    var canGenerateStep: Bool {
        if isUITestMode { return true }
        return isPlus || usage.usage.canGenerateStep
    }
    var canUseAdminQuickStart: Bool {
        if isUITestMode { return true }
        return isPlus || usage.usage.canUseAdminQuickStart
    }
    var usageState: UsageState { usage.usage }

    @discardableResult
    func generateNextStep(input: CaptureInput) async throws -> NextStepModel {
        guard canGenerateStep else { throw UsageError.stepLimitReached }
        let detected = engine.detectCategory(in: input.rawText, preferred: input.preferredCategory)
        let multiplier = calibrator.multiplier(for: detected, in: persistence.calibrationSamples())
        let proposal = try await ai.generateNextStep(input: input, calibrationMultiplier: multiplier)
        let capture = persistence.saveCapture(rawText: input.rawText, source: input.source, language: input.language)
        let step = persistence.saveNextStep(proposal: proposal, capture: capture, taskTitle: proposal.title)
        usage.recordStepGeneration()
        return step
    }

    /// Shrink the given step to the next level and persist the change.
    @discardableResult
    func shrinkCurrentStep(_ step: NextStepModel) -> NextStepProposal {
        let nextLevel = shrinker.nextLevel(after: step.shrinkLevel)
        let proposal = shrinker.shrink(step.proposal, to: nextLevel, language: currentLanguage)
        persistence.updateNextStep(step, proposal: proposal)
        return proposal
    }

    /// No-shame reschedule: shrink + kind message, persisted.
    func rescheduleStep(_ step: NextStepModel, reason: SkipReason) -> (proposal: NextStepProposal, message: String) {
        let result = rescheduler.reschedule(step.proposal, language: currentLanguage, reason: reason)
        persistence.updateNextStep(step, proposal: result.proposal)
        return (result.proposal, result.message)
    }

    // MARK: - Admin Task Reader

    @discardableResult
    func parseAdmin(text: String) async throws -> AdminParseResult {
        guard canUseAdminQuickStart else { throw UsageError.adminLimitReached }
        let result = try await ai.parseAdmin(text: text, language: currentLanguage)
        persistence.saveAdminArtifact(result: result)
        usage.recordAdminQuickStart()
        return result
    }

    // MARK: - Timer

    @discardableResult
    func startTimer(step: NextStepModel, minutes: Int, coStart: CoStartMode = .none) -> TimerSessionModel {
        persistence.startTimer(for: step, plannedMinutes: minutes, coStart: coStart)
    }

    func finishTimer(session: TimerSessionModel, actualSeconds: Int, outcome: TimerOutcome, step: NextStepModel?) {
        persistence.recordTimerOutcome(
            session: session,
            actualSeconds: actualSeconds,
            outcome: outcome,
            step: step,
            isPlus: isPlus
        )
    }

    // MARK: - Recovery

    func activeCapsule() -> RecoveryCapsuleModel? { persistence.activeRecoveryCapsule() }
    func clearActiveCapsule() { persistence.clearActiveRecoveryCapsule() }

    // MARK: - Patterns

    func insights() -> [String] {
        calibrator.insights(samples: persistence.calibrationSamples(), language: currentLanguage)
    }

    func snapshots() -> [CalibrationSnapshot] { persistence.calibrationSnapshots() }

    // MARK: - Data control

    func deleteAllData() { persistence.deleteAllData() }
    func exportJSON() -> String { persistence.exportJSON() }
}
