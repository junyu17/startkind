import Foundation
import Combine

enum StartKindRuntime {
    private static let explicitUITestArguments = ["-UITEST", "-UITEST_AUTH", "-UITEST_PLUS", "-UITEST_ONBOARDING"]

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isTestRuntime: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if explicitUITestArguments.contains(where: { arguments.contains($0) }) {
            return true
        }
#if DEBUG
        return isXCTestHost
#else
        return false
#endif
    }

    static var shouldUseInMemoryPersistence: Bool { isTestRuntime }

    static var shouldSkipStoreKit: Bool {
#if DEBUG
        // Screenshot mode also needs StoreKit's real (empty) entitlements
        // left alone, or `entitlement.load()` would immediately overwrite
        // the Plus state `forcePlusForUITest` just set below.
        isTestRuntime || ScreenshotMode.isActive
#else
        isTestRuntime
#endif
    }

    static var forcePlusForUITest: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-UITEST_PLUS") || ScreenshotMode.forcePlus
#else
        false
#endif
    }

    static var shouldShowOnboarding: Bool {
        arguments.contains("-UITEST_ONBOARDING")
    }

    static var shouldSkipOnboarding: Bool {
#if DEBUG
        (isTestRuntime && !shouldShowOnboarding) || ScreenshotMode.isActive
#else
        isTestRuntime && !shouldShowOnboarding
#endif
    }

#if DEBUG
    private static var isXCTestHost: Bool {
        let processInfo = ProcessInfo.processInfo
        let environment = processInfo.environment
        let previewValue = environment["XCODE_RUNNING_FOR_PREVIEWS"]
        guard previewValue != "1", previewValue != "YES" else { return false }

        let xctestEnvironmentKeys = [
            "XCTestConfigurationFilePath",
            "XCTestBundlePath",
            "XCInjectBundleInto",
            "XCTestSessionIdentifier"
        ]
        if xctestEnvironmentKeys.contains(where: { environment[$0] != nil }) {
            return true
        }

        let processName = processInfo.processName.lowercased()
        return processName.contains("xctest")
    }
#endif
}

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
    let onboarding: OnboardingProfileStore
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
        usageDefaults: UserDefaults = .standard,
        profileDefaults: UserDefaults = .standard,
        aiClient: AIClient? = nil
    ) {
        let testRuntime = StartKindRuntime.isTestRuntime

        let persistence: PersistenceService
        if let stored = try? PersistenceService(inMemory: inMemory || testRuntime) {
            persistence = stored
        } else if let ephemeral = try? PersistenceService(inMemory: true) {
            // Last resort: this session runs on an in-memory store rather than
            // crashing on launch. Nothing persists, but the app stays usable.
            persistence = ephemeral
        } else {
            fatalError("StartKind storage could not be initialized")
        }
        self.persistence = persistence
        self.onboarding = OnboardingProfileStore(
            defaults: profileDefaults,
            skipOnboarding: StartKindRuntime.shouldSkipOnboarding,
            forceOnboarding: StartKindRuntime.shouldShowOnboarding
        )
        self.entitlement = EntitlementService(forcePlusForUITest: StartKindRuntime.forcePlusForUITest)
        self.usage = UsageTracker(defaults: usageDefaults)
        self.vault = PersonalVaultStore()
        self.liveActivity = LiveTimerActivityService()
        self.rescueNotifications = RescueNotificationService()
        self.proofOfStart = ProofOfStartStore()
        self.tinyAdminInbox = TinyAdminInboxStore()
        var preferredLanguage = persistence.profile?.locale ?? ""
        if preferredLanguage.isEmpty {
            // First launch: follow the device, then remember it so a later
            // change in Settings still wins.
            preferredLanguage = StartKindLanguage.systemPreferred
            persistence.updateProfile(locale: preferredLanguage)
        }
#if DEBUG
        // `PersistenceService.init` already called `ensureProfile()`, which
        // defaults a fresh install's locale to "en" - so the line above
        // ignores `-AppleLanguages` entirely on every screenshot run, since
        // each one starts from a fresh `simctl uninstall`. Re-derive it from
        // the system language every screenshot launch instead; harmless to
        // repeat on the later launches that reuse this install.
        if ScreenshotMode.isActive {
            preferredLanguage = ScreenshotMode.systemPreferredLanguage
            persistence.updateProfile(locale: preferredLanguage)
        }
#endif
        LocalizationManager.shared.setLanguage(preferredLanguage)
        self.speech = SpeechService(locale: Locale(identifier: preferredLanguage))
        self.ai = aiClient ?? (testRuntime ? LocalAIClient() : CloudAIClient())
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
        if testRuntime {
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
        speech.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        onboarding.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

#if DEBUG
        seedScreenshotDataIfNeeded()
#endif
    }

    // MARK: - Launch

    func bootstrap() async {
        let skipStoreKit = StartKindRuntime.shouldSkipStoreKit
        LocalizationManager.shared.setLanguage(persistence.profile?.locale ?? "en")
        if !skipStoreKit {
            await entitlement.load()
        }
        speech.refreshAuthorizationState()
        if !skipStoreKit {
            persistence.updateProfile(entitlement: entitlement.state)
        }
#if DEBUG
        if StartKindRuntime.forcePlusForUITest {
            persistence.updateProfile(entitlement: entitlement.state)
        }
#endif
        refreshUsage()
        consumePendingAppIntentAction()
        // Re-assert the entitlement on every launch. The one attempt made at
        // purchase time can fail (offline, server down), and nothing else
        // retried it - leaving someone who paid on Free limits server-side
        // forever, with the app still showing Plus locally.
        if !skipStoreKit, isPlus {
            await syncEntitlementToBackend()
        }
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
        return CoStartRoomModel(hostUserId: hostId, roomType: type, durationMinutes: 25, status: .scheduled, roomCode: roomCode)
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

    /// Create a co-start room for the given step. The timer session is created
    /// only by `beginCoStart` after the person explicitly starts.
    @discardableResult
    func startCoStart(type: CoStartRoomType, step: NextStepModel, stepText: String) async throws -> CoStartRoomModel {
        if type == .friendLink {
            guard canCreateFriendCoStart else { throw CoStartError.friendLimitReached }
            guard !friendCoStartCreationInFlight else { throw CoStartError.friendRoomPublishFailed }
            friendCoStartCreationInFlight = true
            defer { friendCoStartCreationInFlight = false }

            guard let api else { throw CoStartError.friendRoomPublishFailed }
            let serverRoom = try await api.createRoom(
                stepText: stepText,
                displayName: L("costart.host")
            )
            guard let code = serverRoom.code else { throw CoStartError.friendRoomPublishFailed }
            let room = makeCoStartRoom(type: type, roomCode: code)
            room.id = serverRoom.id
            persistCoStartRoom(room, stepText: stepText)
            usage.recordFriendCoStart(isPlus: isPlus)
            return room
        }

        let room = makeCoStartRoom(type: type)
        persistCoStartRoom(room, stepText: stepText)
        return room
    }

    /// Begin the local focus session after the room's ready screen has been
    /// acknowledged. Friend-room start is intentionally local: the backend
    /// exposes presence and outcomes, but not a shared start event.
    @discardableResult
    func beginCoStart(room: CoStartRoomModel, step: NextStepModel) -> TimerSessionModel {
        room.status = .active
        room.startsAt = .now
        let coStart: CoStartMode = (room.roomType == .aiQuiet) ? .ai : .friend
        return persistence.startTimer(for: step, plannedMinutes: 25, coStart: coStart)
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

    /// Leave before focus begins. Hosts end the remote room; guests use the
    /// existing participant-outcome endpoint to mark their departure.
    func leaveCoStart(room: CoStartRoomModel, isGuest: Bool) async {
        room.status = .cancelled
        room.endedAt = .now
        try? persistence.context.save()

        guard room.roomType == .friendLink else { return }
        if isGuest {
            await endCoStartGuest(roomId: room.id, outcome: .abandoned)
        } else {
            await endRemoteCoStartRoom(roomID: room.id.uuidString)
        }
    }

    // MARK: - Co-Start guest join

    /// Set by an incoming join deep link; the UI presents the guest join flow.
    @Published var pendingJoinRoomCode: String?
    @Published var pendingCaptureText: String?
    @Published var pendingRescueRestart = false
    @Published var pendingQuickAction: QuickActionKind?
    /// Set right after a genuine success (a completed step) when it's an
    /// appropriate moment to ask for a review. RootView consumes this and
    /// triggers SwiftUI's `requestReview` action.
    @Published var pendingReviewPrompt = false

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
            status: .scheduled,
            roomCode: serverRoom.code ?? normalizedCode
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

    /// Poll room participants (near-real-time via periodic polling). `nil`
    /// means the backend could not confirm the current state; an empty array
    /// is reserved for a successful response with no active participants.
    func fetchCoStartParticipants(roomId: UUID) async -> [CoStartParticipantInfo]? {
        guard let api else { return nil }
        do {
            let participants = try await api.participants(roomID: roomId.uuidString)
            return participants.map { participant in
                CoStartParticipantInfo(
                    id: participant.id,
                    displayName: participant.displayName,
                    statedStep: participant.statedStep,
                    outcome: participant.outcome
                )
            }
        } catch {
            return nil
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
    var preferredGuestDisplayName: String {
        onboarding.firstName.isEmpty ? L("costart.friend") : onboarding.firstName
    }
    var currentLocale: Locale {
        switch ContentLanguage(currentLanguage) {
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .zhHant: return Locale(identifier: "zh-Hant")
        case .ja: return Locale(identifier: "ja")
        case .ko: return Locale(identifier: "ko")
        case .en: return Locale(identifier: "en")
        }
    }

    func setLanguage(_ language: String) {
        persistence.updateProfile(locale: language)
        LocalizationManager.shared.setLanguage(language)
        speech.updateLocale(language)
        objectWillChange.send()
    }

    func setTone(_ tone: PreferredTone) {
        persistence.updateProfile(tone: tone)
    }

    // MARK: - Capture & Next Step

    var isUITestMode: Bool {
#if DEBUG
        // Screenshot mode reuses this gate too: it suppresses the same
        // review-request and rescue-notification prompts that would
        // otherwise cover the app while a screenshot is being taken, and it
        // needs the same usage-limit bypass the seeded history would
        // otherwise run into.
        StartKindRuntime.isTestRuntime || ScreenshotMode.isActive
#else
        StartKindRuntime.isTestRuntime
#endif
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
        let multiplier = calibrator.multiplier(for: detected, in: persistence.calibrationSamples(days: analysisHistoryDays))
        var proposal = engine.generate(input, calibrationMultiplier: multiplier)
        if let energy {
            proposal = energyMatcher.apply(proposal, energy: energy, language: input.language)
        }
        let capture = persistence.saveCapture(rawText: input.rawText, source: input.source, language: input.language)
        let step = persistence.saveNextStep(proposal: proposal, capture: capture, taskTitle: proposal.title)
        widgetNextStepStore.save(proposal: proposal)
        usage.recordStepGeneration()
        refineNextStepInBackground(
            step,
            localSnapshot: step.proposal,
            input: input,
            calibrationMultiplier: multiplier,
            energy: energy
        )
        return step
    }

    private func refineNextStepInBackground(
        _ step: NextStepModel,
        localSnapshot: NextStepProposal,
        input: CaptureInput,
        calibrationMultiplier: Double,
        energy: EnergyLevel?
    ) {
        let ai = ai
        Task { [weak self, weak step] in
            let clock = ContinuousClock()
            let startedAt = clock.now
            guard var refined = try? await ai.generateNextStep(
                input: input,
                calibrationMultiplier: calibrationMultiplier
            ),
            startedAt.duration(to: clock.now) <= .seconds(1),
            refined.generatedBy == .cloudAI,
            let self,
            let step,
            step.status == .suggested,
            step.startedAt == nil,
            step.proposal == localSnapshot else { return }

            if let energy {
                refined = energyMatcher.apply(refined, energy: energy, language: input.language)
            }
            persistence.updateNextStep(step, proposal: refined)
            widgetNextStepStore.save(proposal: refined)
        }
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
            persistence.updateNextStep(step, proposal: proposal)
            return step
        }
        return createFrictionPresetStep(.tooVague, category: .other)
    }

    /// Completing a reduced rung means the user is ready for one larger action,
    /// not that the original task is finished. Reuse the same persisted step so
    /// its task identity and timer history stay connected.
    @discardableResult
    func reopenNextLargerStep(_ step: NextStepModel, rootProposal: NextStepProposal) -> NextStepProposal? {
        guard step.shrinkLevel > rootProposal.shrinkLevel,
              let targetLevel = ShrinkLevel(rawValue: step.shrinkLevel.rawValue - 1) else {
            return nil
        }

        let proposal = targetLevel == rootProposal.shrinkLevel
            ? rootProposal
            : shrinker.shrink(rootProposal, to: targetLevel, language: currentLanguage)
        step.status = .suggested
        step.startedAt = nil
        step.completedAt = nil
        persistence.updateNextStep(step, proposal: proposal)
        return proposal
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
            if ReviewPrompter.recordValueMoment() {
                pendingReviewPrompt = true
            }
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
        startProfilePlanner.profile(samples: persistence.calibrationSamples(days: analysisHistoryDays))
    }

    // MARK: - Co-start continuity

    func savePreferredCoStarter(displayName: String, roomCode: String?) {
        coStartContinuity.save(displayName: displayName, roomCode: roomCode)
    }

    // MARK: - Patterns

    func insights() -> [String] {
        calibrator.insights(samples: persistence.calibrationSamples(days: analysisHistoryDays), language: currentLanguage)
    }

    func snapshots() -> [CalibrationSnapshot] { persistence.calibrationSnapshots(days: analysisHistoryDays) }

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
            samples: persistence.calibrationSamples(days: analysisHistoryDays),
            language: currentLanguage
        )
    }

    // MARK: - Data control

    func deleteAllData() {
        persistence.deleteAllData()
        onboarding.reset()
        vault.clear()
        proofOfStart.clear()
        tinyAdminInbox.clear()
        frictionMemory.clear()
        startScripts.clear()
        widgetNextStepStore.clear()
        dailyOneThing.clear()
        coStartContinuity.clear()
        persistence.updateProfile(entitlement: entitlement.state)
    }

    func exportJSON() -> String { persistence.exportJSON() }

    static func normalizedRoomCode(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    static func isValidRoomCode(_ value: String) -> Bool {
        normalizedRoomCode(value).count == 6
    }

    private var analysisHistoryDays: Int? {
        isPlus ? nil : UsageLimits.freeHistoryDays
    }
}

/// The app ships English, Simplified and Traditional Chinese, Japanese, and
/// Korean; anything else falls back to English. Used on first launch, before
/// the person has chosen a language.
enum StartKindLanguage {
    static var systemPreferred: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        switch ContentLanguage(preferred) {
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .ja: return "ja"
        case .ko: return "ko"
        case .en: return "en"
        }
    }
}
