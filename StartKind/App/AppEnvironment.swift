import Foundation
import Combine

enum UsageError: LocalizedError {
    case stepLimitReached, adminLimitReached

    var errorDescription: String? {
        switch self {
        case .stepLimitReached: return L("error.usage.stepLimit")
        case .adminLimitReached: return L("error.usage.adminLimit")
        }
    }
}

enum CoStartError: Error {
    case friendLimitReached
    case friendRoomPublishFailed
}

/// The composition root. Holds all services and domain components, and exposes
/// the high-level actions the UI drives. All access is main-actor bound.
@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceService
    let entitlement: EntitlementService
    let usage: UsageTracker
    let vault: PersonalVaultStore
    let liveActivity: LiveTimerActivityService
    let rescueNotifications: RescueNotificationService
    let proofOfStart: ProofOfStartStore
    let tinyAdminInbox: TinyAdminInboxStore
    let speech: SpeechService
    let ai: AIClient
    let api: StartKindAPI?

    let engine: NextStepEngine
    let shrinker: TaskShrinker
    let rescheduler: Rescheduler
    let calibrator: TimeCalibrator
    let autopilot: AutopilotPlanner
    let frictionMap: FrictionMap
    let energyMatcher: EnergyMatcher
    let frictionPresetPlanner: FrictionPresetPlanner
    let yesterdayRescuePlanner: YesterdayRescuePlanner
    let emergencyTinyModePlanner: EmergencyTinyModePlanner
    let dayPartPlanner: DayPartPlanner
    let calendarSoftLandingPlanner: CalendarSoftLandingPlanner
    let gentleReviewPlanner: GentleReviewPlanner
    let frictionForecastPlanner: FrictionForecastPlanner
    let frictionMemory: FrictionMemoryStore
    let startScripts: StartScriptStore
    let widgetNextStepStore: WidgetNextStepStore
    let dailyOneThing: DailyOneThingStore
    let coStartContinuity: CoStartContinuityStore
    let resumeCardPlanner: ResumeCardPlanner
    let startLadderPlanner: StartLadderPlanner
    let actionPrepPlanner: ActionPrepPlanner
    let dailyOneThingPlanner: DailyOneThingPlanner
    let startProfilePlanner: StartProfilePlanner
    let urgentAdminPlanner: UrgentAdminPlanner

    private var friendCoStartCreationInFlight = false
    private var cancellables = Set<AnyCancellable>()

    init(
        inMemory: Bool = false,
        usageDefaults: UserDefaults = .standard
    ) {
        let persistence: PersistenceService
        if let stored = try? PersistenceService(inMemory: inMemory) {
            persistence = stored
        } else if let ephemeral = try? PersistenceService(inMemory: true) {
            // Last resort: this session runs on an in-memory store rather than
            // crashing on launch. Nothing persists, but the app stays usable.
            persistence = ephemeral
        } else {
            fatalError("StartKind storage could not be initialized")
        }
        self.persistence = persistence
        self.entitlement = EntitlementService()
        self.usage = UsageTracker(defaults: usageDefaults)
        self.vault = PersonalVaultStore()
        self.liveActivity = LiveTimerActivityService()
        self.rescueNotifications = RescueNotificationService()
        self.proofOfStart = ProofOfStartStore()
        self.tinyAdminInbox = TinyAdminInboxStore()
        self.speech = SpeechService()
        let launchArgs = ProcessInfo.processInfo.arguments
        let uiTestMode = launchArgs.contains("-UITEST") || launchArgs.contains("-UITEST_AUTH")
        self.ai = uiTestMode ? LocalAIClient() : CloudAIClient()
        self.api = StartKindAPI()
        self.engine = NextStepEngine()
        self.shrinker = TaskShrinker()
        self.rescheduler = Rescheduler()
        self.calibrator = TimeCalibrator()
        self.autopilot = AutopilotPlanner()
        self.frictionMap = FrictionMap()
        self.energyMatcher = EnergyMatcher()
        self.frictionPresetPlanner = FrictionPresetPlanner()
        self.yesterdayRescuePlanner = YesterdayRescuePlanner()
        self.emergencyTinyModePlanner = EmergencyTinyModePlanner()
        self.dayPartPlanner = DayPartPlanner()
        self.calendarSoftLandingPlanner = CalendarSoftLandingPlanner()
        self.gentleReviewPlanner = GentleReviewPlanner()
        self.frictionForecastPlanner = FrictionForecastPlanner()
        self.frictionMemory = FrictionMemoryStore()
        self.startScripts = StartScriptStore()
        self.widgetNextStepStore = WidgetNextStepStore()
        self.dailyOneThing = DailyOneThingStore()
        self.coStartContinuity = CoStartContinuityStore()
        self.resumeCardPlanner = ResumeCardPlanner()
        self.startLadderPlanner = StartLadderPlanner()
        self.actionPrepPlanner = ActionPrepPlanner()
        self.dailyOneThingPlanner = DailyOneThingPlanner()
        self.startProfilePlanner = StartProfilePlanner()
        self.urgentAdminPlanner = UrgentAdminPlanner()
        if uiTestMode {
            self.vault.clear()
            self.proofOfStart.clear()
            self.tinyAdminInbox.clear()
            self.frictionMemory.clear()
            self.startScripts.clear()
            self.widgetNextStepStore.clear()
            self.dailyOneThing.clear()
            self.coStartContinuity.clear()
        }

        // Keep the persisted profile entitlement in sync with StoreKit.
        entitlement.$state
            .removeDuplicates()
            .sink { [weak persistence] state in
                persistence?.updateProfile(entitlement: state)
            }
            .store(in: &cancellables)

        entitlement.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        usage.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Launch

    func bootstrap() async {
        let args = ProcessInfo.processInfo.arguments
        let skipStoreKit = args.contains("-UITEST") || args.contains("-UITEST_AUTH")
        LocalizationManager.shared.setLanguage(persistence.profile?.locale ?? "en")
        if !skipStoreKit {
            await entitlement.load()
        }
        speech.refreshAuthorizationState()
        if !skipStoreKit {
            persistence.updateProfile(entitlement: entitlement.state)
        }
        refreshUsage()
        consumePendingAppIntentAction()
    }

    func refreshUsage() {
        _ = usage.currentUsage()
    }

    func consumePendingAppIntentAction() {
        guard let kind = StartKindIntentActionStore.consume() else { return }
        pendingQuickAction = kind
    }

    // MARK: - Entitlement sync

    /// Hand the backend Apple's signed proof of the entitlement so it can gate
    /// the AI proxy. The backend verifies the signature itself; it never takes
    /// the app's word for what tier this device is on.
    func syncEntitlementToBackend() async {
        guard let api, let signed = entitlement.signedTransaction else { return }
        _ = try? await api.verifyTransaction(signed)
    }

    // MARK: - Co-Start

    private func makeCoStartRoom(type: CoStartRoomType, roomCode: String? = nil) -> CoStartRoomModel {
        let hostId = persistence.userId
        return CoStartRoomModel(hostUserId: hostId, roomType: type, durationMinutes: 25, status: .active, roomCode: roomCode, startsAt: .now)
    }

    private func persistCoStartRoom(_ room: CoStartRoomModel, stepText: String) {
        persistence.context.insert(room)
        let me = CoStartParticipantModel(roomId: room.id, userId: persistence.userId, displayName: L("costart.you"), statedStep: stepText)
        persistence.context.insert(me)
        if room.roomType == .aiQuiet {
            let ai = CoStartParticipantModel(roomId: room.id, userId: nil, displayName: L("costart.ai"), statedStep: L("costart.aiQuietPresence"))
            persistence.context.insert(ai)
        }
        try? persistence.context.save()
    }

    /// Start a co-start room + a 25-min timer session for the given step.
    @discardableResult
    func startCoStart(type: CoStartRoomType, step: NextStepModel, stepText: String) async throws -> (room: CoStartRoomModel, session: TimerSessionModel) {
        if type == .friendLink {
            guard canCreateFriendCoStart else { throw CoStartError.friendLimitReached }
            guard !friendCoStartCreationInFlight else { throw CoStartError.friendRoomPublishFailed }
            friendCoStartCreationInFlight = true
            defer { friendCoStartCreationInFlight = false }

            guard let api else { throw CoStartError.friendRoomPublishFailed }
            let serverRoom = try await api.createRoom()
            guard let code = serverRoom.code else { throw CoStartError.friendRoomPublishFailed }
            let room = makeCoStartRoom(type: type, roomCode: code)
            room.id = serverRoom.id
            persistCoStartRoom(room, stepText: stepText)
            let session = persistence.startTimer(for: step, plannedMinutes: 25, coStart: .friend)
            usage.recordFriendCoStart(isPlus: isPlus)
            return (room, session)
        }

        let room = makeCoStartRoom(type: type)
        persistCoStartRoom(room, stepText: stepText)
        let coStart: CoStartMode = (type == .aiQuiet) ? .ai : .friend
        let session = persistence.startTimer(for: step, plannedMinutes: 25, coStart: coStart)
        return (room, session)
    }

    func endCoStart(room: CoStartRoomModel, session: TimerSessionModel, outcome: TimerOutcome, step: NextStepModel?) {
        room.status = .ended
        room.endedAt = .now
        let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
        persistence.recordTimerOutcome(session: session, actualSeconds: elapsed, outcome: outcome, step: step, isPlus: isPlus)
        try? persistence.context.save()
        if room.roomType == .friendLink {
            Task { await endRemoteCoStartRoom(roomID: room.id.uuidString) }
        }
    }

    /// Invite link for a friend co-start room (deep link with a human-enterable code).
    func inviteLink(for room: CoStartRoomModel) -> URL? {
        guard let code = room.roomCode else { return nil }
        var components = URLComponents(string: "startkind://join")
        components?.queryItems = [URLQueryItem(name: "code", value: code)]
        return components?.url
    }

    private func endRemoteCoStartRoom(roomID: String) async {
        guard let api else { return }
        try? await api.endRoom(roomID: roomID)
    }

    // MARK: - Co-Start guest join

    /// Set by an incoming join deep link; the UI presents the guest join flow.
    @Published var pendingJoinRoomCode: String?
    @Published var pendingCaptureText: String?
    @Published var pendingRescueRestart = false
    @Published var pendingQuickAction: QuickActionKind?

    func handleJoinURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if components.host == "capture" {
            pendingCaptureText = components.queryItems?.first(where: { $0.name == "text" })?.value
            return
        }
        if components.host == "start" {
            return
        }
        if components.host == "rescue" {
            pendingRescueRestart = true
            return
        }
        if components.host == "quick",
           let kindValue = components.queryItems?.first(where: { $0.name == "kind" })?.value,
           let kind = QuickActionKind(rawValue: kindValue) {
            pendingQuickAction = kind
            return
        }
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           Self.isValidRoomCode(code) {
            pendingJoinRoomCode = code
            return
        }
    }

    /// Join a co-start room with the 6-digit code a friend reads or shares.
    func joinCoStartRoom(code: String, stepText: String, displayName: String) async throws -> CoStartRoomModel? {
        guard let api else { return nil }
        let normalizedCode = Self.normalizedRoomCode(code)
        guard Self.isValidRoomCode(normalizedCode) else { return nil }
        let serverRoom = try await api.joinRoom(code: normalizedCode, stepText: stepText, displayName: displayName)
        let room = CoStartRoomModel(
            id: serverRoom.id,
            hostUserId: persistence.userId,
            roomType: .friendLink,
            durationMinutes: serverRoom.durationMinutes,
            status: CoStartRoomStatus(rawValue: serverRoom.status) ?? .active,
            roomCode: serverRoom.code ?? normalizedCode,
            startsAt: serverRoom.startsAt
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
        guard let api else { return [] }
        let participants = (try? await api.participants(roomID: roomId.uuidString)) ?? []
        return participants.map { participant in
            CoStartParticipantInfo(
                id: participant.id,
                displayName: participant.displayName,
                statedStep: participant.statedStep,
                outcome: participant.outcome
            )
        }
    }

    /// Guest ends: update own participant outcome.
    func endCoStartGuest(roomId: UUID, outcome: TimerOutcome) async {
        guard let api else { return }
        try? await api.setOutcome(roomID: roomId.uuidString, outcome: outcome.rawValue)
    }

    func handleQuickAction(type: String) {
        guard let kind = QuickActionKind(shortcutType: type) else { return }
        pendingQuickAction = kind
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
        return usage.canGenerateStep(isPlus: isPlus)
    }
    var canUseAdminQuickStart: Bool {
        if isUITestMode { return true }
        return usage.canUseAdminQuickStart(isPlus: isPlus)
    }
    var canCreateFriendCoStart: Bool {
        if isUITestMode { return true }
        return usage.canCreateFriendCoStart(isPlus: isPlus)
    }
    var usageState: UsageState { usage.usage }

    @discardableResult
    func generateNextStep(input: CaptureInput, energy: EnergyLevel? = nil) async throws -> NextStepModel {
        guard canGenerateStep else { throw UsageError.stepLimitReached }
        let detected = engine.detectCategory(in: input.rawText, preferred: input.preferredCategory)
        if emergencyTinyModePlanner.detectsTrigger(input.rawText) {
            return createLocalNextStep(
                proposal: emergencyTinyModePlanner.proposal(language: input.language),
                sourceText: input.rawText,
                source: input.source
            )
        }
        let multiplier = calibrator.multiplier(for: detected, in: persistence.calibrationSamples())
        var proposal = try await ai.generateNextStep(input: input, calibrationMultiplier: multiplier)
        if let energy {
            proposal = energyMatcher.apply(proposal, energy: energy, language: input.language)
        }
        let capture = persistence.saveCapture(rawText: input.rawText, source: input.source, language: input.language)
        let step = persistence.saveNextStep(proposal: proposal, capture: capture, taskTitle: proposal.title)
        widgetNextStepStore.save(proposal: proposal)
        usage.recordStepGeneration()
        return step
    }

    @discardableResult
    func createLocalNextStep(proposal: NextStepProposal, sourceText: String, source: CaptureSource = .manual) -> NextStepModel {
        let capture = persistence.saveCapture(rawText: sourceText, source: source, language: currentLanguage)
        let step = persistence.saveNextStep(proposal: proposal, capture: capture, taskTitle: proposal.title)
        widgetNextStepStore.save(proposal: proposal)
        return step
    }

    @discardableResult
    func createStartLadderStep(from step: NextStepModel, minutes: Int) -> NextStepModel {
        let proposal = startLadderPlanner.proposal(from: step.proposal, minutes: minutes, language: currentLanguage)
        return createLocalNextStep(proposal: proposal, sourceText: step.proposal.step, source: .manual)
    }

    func actionPrep(for step: NextStepModel) -> ActionPrepPlan? {
        actionPrepPlanner.plan(for: step.proposal, language: currentLanguage)
    }

    @discardableResult
    func createAutopilotStep() -> NextStepModel {
        let proposal = autopilot.proposal(
            capsule: activeCapsule(),
            vaultItems: vault.items,
            templates: MicroTemplateLibrary.templates(language: currentLanguage)
        )
        return createLocalNextStep(proposal: proposal, sourceText: L("autopilot.source"), source: .manual)
    }

    @discardableResult
    func createFrictionPresetStep(_ preset: FrictionPreset, category: TaskCategory?) -> NextStepModel {
        let chosenCategory = category ?? .other
        let proposal = frictionPresetPlanner.proposal(
            for: preset,
            category: chosenCategory,
            language: currentLanguage
        )
        frictionMemory.record(category: chosenCategory, preset: preset)
        return createLocalNextStep(proposal: proposal, sourceText: "friction:\(preset.rawValue)", source: .manual)
    }

    @discardableResult
    func createStuckStep(current step: NextStepModel?) -> NextStepModel {
        if let step {
            let proposal = shrinker.shrink(step.proposal, to: shrinker.nextLevel(after: step.shrinkLevel), language: currentLanguage)
            return createLocalNextStep(proposal: proposal, sourceText: L("stuck.source"), source: .manual)
        }
        return createFrictionPresetStep(.tooVague, category: .other)
    }

    func yesterdayRescueProposal() -> NextStepProposal? {
        yesterdayRescuePlanner.proposal(
            activeCapsule: activeCapsule(),
            recentSteps: persistence.recentNextSteps(days: 2),
            language: currentLanguage
        )
    }

    @discardableResult
    func createYesterdayRescueStep() -> NextStepModel? {
        guard let proposal = yesterdayRescueProposal() else { return nil }
        return createLocalNextStep(proposal: proposal, sourceText: L("yesterday.source"), source: .manual)
    }

    @discardableResult
    func createDayPartStep() -> NextStepModel {
        let proposal = dayPartPlanner.proposal(
            activeCapsule: activeCapsule(),
            recentSteps: persistence.recentNextSteps(days: 2),
            language: currentLanguage
        )
        return createLocalNextStep(proposal: proposal, sourceText: L("daypart.source"), source: .manual)
    }

    @discardableResult
    func createEmergencyTinyStep() -> NextStepModel {
        let proposal = emergencyTinyModePlanner.proposal(language: currentLanguage)
        return createLocalNextStep(proposal: proposal, sourceText: L("emergency.source"), source: .manual)
    }

    func frictionMemoryProposal(category: TaskCategory?) -> NextStepProposal? {
        frictionMemory.proposal(for: category ?? .other, language: currentLanguage)
    }

    func frictionForecast(text: String, category: TaskCategory?) -> FrictionForecast? {
        frictionForecastPlanner.forecast(
            text: text,
            category: category,
            memory: frictionMemory.signals,
            language: currentLanguage
        )
    }

    @discardableResult
    func createFrictionForecastStep(text: String, category: TaskCategory?) -> NextStepModel? {
        guard let forecast = frictionForecast(text: text, category: category) else { return nil }
        return createLocalNextStep(proposal: forecast.proposal, sourceText: "frictionForecast:\(forecast.preset.rawValue)", source: .manual)
    }

    @discardableResult
    func createFrictionMemoryStep(category: TaskCategory?) -> NextStepModel? {
        guard let proposal = frictionMemoryProposal(category: category) else { return nil }
        return createLocalNextStep(proposal: proposal, sourceText: L("frictionMemory.source"), source: .manual)
    }

    @discardableResult
    func saveStartScript(from step: NextStepModel) -> StartScript {
        startScripts.add(title: step.title, body: step.proposal.step, category: step.category)
    }

    @discardableResult
    func createStartScriptStep(_ script: StartScript) -> NextStepModel {
        createLocalNextStep(proposal: startScripts.proposal(from: script, language: currentLanguage), sourceText: L("startScript.source"), source: .manual)
    }

    func calendarSoftLandingProposal(title: String, daysFromNow: Int) -> NextStepProposal? {
        let start = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        return calendarSoftLandingPlanner.proposal(for: CalendarSoftLandingEvent(title: title, startDate: start), language: currentLanguage)
    }

    @discardableResult
    func createCalendarSoftLandingStep(title: String, daysFromNow: Int) -> NextStepModel? {
        guard let proposal = calendarSoftLandingProposal(title: title, daysFromNow: daysFromNow) else { return nil }
        return createLocalNextStep(proposal: proposal, sourceText: title, source: .manual)
    }

    @discardableResult
    func recordProofOfStart(step: NextStepModel) -> ProofOfStartEvent {
        proofOfStart.record(stepId: step.id, title: step.title, category: step.category)
    }

    var proofOfStartCount: Int {
        proofOfStart.recentCount()
    }

    @discardableResult
    func captureAdminInbox(text: String) async throws -> NextStepModel {
        let result = try await parseAdmin(text: text)
        tinyAdminInbox.add(rawText: text, proposal: result.oneNextStep)
        return createLocalNextStep(proposal: result.oneNextStep, sourceText: text, source: .text)
    }

    func urgentAdminSignal(for text: String, category: TaskCategory? = nil) -> UrgentAdminSignal? {
        urgentAdminPlanner.signal(in: text, category: category, language: currentLanguage)
    }

    @discardableResult
    func createUrgentAdminStep(from text: String, category: TaskCategory? = nil) -> NextStepModel? {
        guard let signal = urgentAdminSignal(for: text, category: category) else { return nil }
        return createLocalNextStep(proposal: signal.proposal, sourceText: text, source: .text)
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
        let session = persistence.startTimer(for: step, plannedMinutes: minutes, coStart: coStart)
        liveActivity.start(step: step, plannedMinutes: minutes)
        return session
    }

    func finishTimer(session: TimerSessionModel, actualSeconds: Int, outcome: TimerOutcome, step: NextStepModel?, blocker: BlockerReason? = nil, returnNote: String? = nil) {
        persistence.recordTimerOutcome(
            session: session,
            actualSeconds: actualSeconds,
            outcome: outcome,
            step: step,
            isPlus: isPlus,
            blocker: blocker,
            returnNote: returnNote
        )
        liveActivity.end()
        if isUITestMode { return }
        if outcome == .completed {
            rescueNotifications.cancelRescue()
        } else if step != nil {
            rescueNotifications.scheduleRescue()
        }
    }

    // MARK: - Recovery

    func activeCapsule() -> RecoveryCapsuleModel? { persistence.activeRecoveryCapsule() }
    func clearActiveCapsule() { persistence.clearActiveRecoveryCapsule() }
    func resumeCardContext() -> ResumeCardContext? {
        activeCapsule().map { resumeCardPlanner.context(for: $0) }
    }

    // MARK: - Daily one thing

    func dailyOneThingCandidates() -> [DailyOneThingCandidate] {
        var candidates: [DailyOneThingCandidate] = []
        if let capsule = activeCapsule() {
            candidates.append(DailyOneThingCandidate(id: capsule.id, proposal: capsule.resumeProposal, source: .recovery))
        }
        candidates.append(contentsOf: tinyAdminInbox.items.map {
            DailyOneThingCandidate(id: $0.id, proposal: $0.proposal, source: .admin)
        })
        candidates.append(contentsOf: vault.items.map {
            DailyOneThingCandidate(
                id: $0.id,
                proposal: NextStepProposal(
                    title: $0.title,
                    step: $0.body,
                    timerMinutes: 5,
                    stopCondition: L("dailyOne.stop"),
                    category: $0.category ?? .other,
                    shrinkLevel: .two,
                    generatedBy: .user,
                    whyThisStep: L("dailyOne.why")
                ),
                source: .vault
            )
        })
        return candidates
    }

    func dailyOneThingSelection() -> DailyOneThing? {
        dailyOneThing.select(from: dailyOneThingCandidates(), planner: dailyOneThingPlanner)
    }

    @discardableResult
    func createDailyOneThingStep() -> NextStepModel? {
        guard let item = dailyOneThingSelection() else { return nil }
        return createLocalNextStep(proposal: item.proposal, sourceText: L("dailyOne.source"), source: .manual)
    }

    func replaceDailyOneThing() {
        _ = dailyOneThing.replace(from: dailyOneThingCandidates(), planner: dailyOneThingPlanner)
        objectWillChange.send()
    }

    func dismissDailyOneThing() {
        dailyOneThing.dismiss()
        objectWillChange.send()
    }

    // MARK: - Start profile

    func startProfile() -> StartProfile {
        startProfilePlanner.profile(samples: persistence.calibrationSamples())
    }

    // MARK: - Co-start continuity

    func savePreferredCoStarter(displayName: String, roomCode: String?) {
        coStartContinuity.save(displayName: displayName, roomCode: roomCode)
    }

    // MARK: - Patterns

    func insights() -> [String] {
        calibrator.insights(samples: persistence.calibrationSamples(), language: currentLanguage)
    }

    func snapshots() -> [CalibrationSnapshot] { persistence.calibrationSnapshots() }

    func frictionInsights() -> [FrictionInsight] {
        frictionMap.insights(
            capsules: persistence.recoveryCapsules(),
            snapshots: snapshots()
        )
    }

    func gentleReviewSummary() -> GentleReviewSummary {
        gentleReviewPlanner.summary(
            proofs: proofOfStart.events,
            frictionSignals: frictionMemory.signals,
            samples: persistence.calibrationSamples(),
            language: currentLanguage
        )
    }

    // MARK: - Data control

    func deleteAllData() {
        persistence.deleteAllData()
        vault.clear()
        proofOfStart.clear()
        tinyAdminInbox.clear()
        frictionMemory.clear()
        startScripts.clear()
        widgetNextStepStore.clear()
        dailyOneThing.clear()
        coStartContinuity.clear()
    }

    func exportJSON() -> String { persistence.exportJSON() }

    static func normalizedRoomCode(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    static func isValidRoomCode(_ value: String) -> Bool {
        normalizedRoomCode(value).count == 6
    }
}
