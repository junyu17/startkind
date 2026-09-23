import SwiftUI
import UIKit

fileprivate struct RoomCodeTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accessibilityIdentifier: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textFieldEditingChanged(_:)),
            for: .editingChanged
        )
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.placeholder = placeholder
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.accessibilityIdentifier = accessibilityIdentifier
        textField.accessibilityLabel = placeholder
        textField.text = Self.normalizedDigits(text)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused

        uiView.placeholder = placeholder
        uiView.keyboardType = .numberPad
        uiView.textContentType = .oneTimeCode
        uiView.accessibilityIdentifier = accessibilityIdentifier
        uiView.accessibilityLabel = placeholder

        let normalizedText = Self.normalizedDigits(text)
        if uiView.text != normalizedText {
            uiView.text = normalizedText
        }

        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    private static func normalizedDigits(_ value: String) -> String {
        var result = ""
        for scalar in value.unicodeScalars {
            guard CharacterSet.decimalDigits.contains(scalar) else { continue }
            guard result.count < 6 else { break }
            result.append(String(scalar))
        }
        return result
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused.wrappedValue = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            isFocused.wrappedValue = false
            return true
        }

        @objc func textFieldEditingChanged(_ textField: UITextField) {
            let normalized = RoomCodeTextField.normalizedDigits(textField.text ?? "")
            if textField.text != normalized {
                textField.text = normalized
            }
            text.wrappedValue = normalized
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return false }

            let candidate = currentText.replacingCharacters(in: stringRange, with: string)
            let normalized = RoomCodeTextField.normalizedDigits(candidate)
            let remainingCapacity = max(
                0,
                6 - RoomCodeTextField.normalizedDigits(
                    currentText.replacingCharacters(in: stringRange, with: "")
                ).utf16.count
            )

            if candidate == normalized && string.utf16.count <= remainingCapacity {
                return true
            }

            let rawCaretOffset = range.location + string.utf16.count
            let candidatePrefixLength = min(rawCaretOffset, candidate.utf16.count)
            let candidatePrefix = (candidate as NSString).substring(
                with: NSRange(location: 0, length: candidatePrefixLength)
            )
            let normalizedCaretOffset = RoomCodeTextField.normalizedDigits(candidatePrefix).utf16.count

            textField.text = normalized
            text.wrappedValue = normalized

            if let caretPosition = textField.position(
                from: textField.beginningOfDocument,
                offset: min(normalizedCaretOffset, normalized.utf16.count)
            ) {
                textField.selectedTextRange = textField.textRange(from: caretPosition, to: caretPosition)
            }

            return false
        }
    }
}

struct StartView: View {
    private struct CoStartRoute: Identifiable {
        let id = UUID()
        let step: NextStepModel
        let initialMode: CoStartRoomType?
    }

    private struct JoinedCoStartRoute: Identifiable {
        let id = UUID()
        let room: CoStartRoomModel
        let stepText: String
    }

    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var inputText = ""
    @State private var joinRoomCode = ""
    @FocusState private var focusedField: FocusedField?
    @State private var lastSource: CaptureSource = .text
    @State private var selectedCategory: TaskCategory?
    @State private var selectedEnergy: EnergyLevel?
    @State private var currentStep: NextStepModel?
    @State private var rootProposalBeforeShrink: NextStepProposal?
    @State private var isLoading = false
    @State private var isJoiningRoom = false
    @State private var errorMessage: String?
    @State private var rescheduleMessage: String?
    @State private var proofMessage: String?
    @State private var showPlan = false
    @State private var adminReaderInitialMode: AdminQuickReaderView.InitialMode?
    @State private var showTemplates = false
    @State private var showVault = false
    @State private var vaultMessage: String?
    @State private var adminInboxText = ""
    @State private var calendarEventTitle = ""
    @State private var calendarDaysFromNow = 1
    @State private var dailyOneThing: DailyOneThing?

    @State private var showPaywall = false
    @State private var paywallReason: PaywallTrigger = .stepLimit
    @State private var moreWaysExpanded = false
    @State private var scanOrPasteExpanded = false
    @State private var reuseStartExpanded = false
    @State private var coStartExpanded = false
    @State private var matchFeelExpanded = false
    @State private var planAheadExpanded = false

    @State private var timerRoute: TimerRoute?
    @State private var coStartRoute: CoStartRoute?
    @State private var joinedCoStartRoute: JoinedCoStartRoute?
    @State private var pendingSaveStart: SavedStartDraft?
    @State private var savePrompt: SavedStartDraft?
    @State private var savedStartConfirmation: SavedStartDraft?

    /// Anchor for the produced step card. Every "give me a step" action renders
    /// its result below the fold, so without scrolling to it the screen looks
    /// like nothing happened - the worst possible feedback for this app.
    private static let stepAnchor = "start.nextStepCard"
    /// A failure can arrive while an earlier step is still on screen, so the
    /// two cannot share a scroll anchor.
    private static let errorAnchor = "start.errorBanner"

    private enum FocusedField: Hashable {
        case taskInput
        case roomCode
        case adminInbox
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScrollViewReader { proxy in
                VStack(spacing: Theme.spacing16) {
                    headerBand
                    primaryStartPanel

                    // The answer belongs next to the question. Every control
                    // that produces a step lives in primaryStartPanel or just
                    // below it, so the result - and the wait before it - has
                    // to render here rather than under the fold, where a tap
                    // looks like it did nothing.
                    if isLoading {
                        StepSkeleton()
                            .id(Self.stepAnchor)
                            .transition(.opacity)
                    } else if let step = currentStep {
                        VStack(spacing: Theme.spacing16) {
                            NextStepCard(
                                step: step,
                                showPlan: $showPlan,
                                onStart: { startTimer(for: step) },
                                onShrink: { shrink(step) },
                                onSkip: { skip(step) },
                                actionPrep: env.actionPrep(for: step),
                                onPrepare: { plan in
                                    if let url = plan.url { openURL(url) }
                                },
                                onUseStartLadder: { minutes in
                                    currentStep = env.createStartLadderStep(from: step, minutes: minutes)
                                    showPlan = false
                                },
                                onCoStart: {
                                    coStartRoute = CoStartRoute(step: step, initialMode: nil)
                                },
                                onSaveToVault: {
                                    env.vault.add(title: step.proposal.title, body: step.proposal.step, category: step.category)
                                    vaultMessage = L("vault.saved")
                                }
                            )
                            proofOfStartPanel(step)
                        }
                        // No accessibility identifier here: putting one on the
                        // wrapper collapses the card into a single element and
                        // hides everything inside it from VoiceOver.
                        .id(Self.stepAnchor)
                    }

                    if let errorMessage {
                        KindBanner(text: errorMessage, tone: .warning)
                            .id(Self.errorAnchor)
                            .transition(.opacity)
                            .accessibilityIdentifier("start.error")
                    }

                    moreWaysPanel
                    usageLine

                    if currentStep == nil && !isLoading && errorMessage == nil {
                        emptyHint
                    }

                    if let rescheduleMessage {
                        KindBanner(text: rescheduleMessage)
                            .transition(.opacity)
                    }
                    if let vaultMessage {
                        KindBanner(text: vaultMessage)
                            .transition(.opacity)
                    }
                    if let proofMessage {
                        KindBanner(text: proofMessage)
                            .transition(.opacity)
                    }
                    if let savedStartConfirmation {
                        SavedStartConfirmationBanner(title: savedStartConfirmation.title) {
                            self.savedStartConfirmation = nil
                            showVault = true
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.spacing16)
                .padding(.vertical, Theme.spacing16)
                .animation(reduceMotion ? nil : .easeInOut, value: rescheduleMessage)
                .onChange(of: currentStep?.id) { _, id in
                    rootProposalBeforeShrink = nil
                    guard id != nil else { return }
                    // A step arriving supersedes whatever failed before it.
                    // Eighteen call sites produce steps; stating the rule here
                    // is the only version of it that stays true.
                    errorMessage = nil
                    withAnimation(reduceMotion ? nil : .easeInOut) {
                        proxy.scrollTo(Self.stepAnchor, anchor: .top)
                    }
                }
                // A second, distinct confirmation when the step actually
                // lands, so the arrival is felt as well as seen.
                .sensoryFeedback(.success, trigger: currentStep?.id) { _, id in id != nil }
                .onChange(of: errorMessage) { _, message in
                    guard message != nil else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut) {
                        proxy.scrollTo(Self.errorAnchor, anchor: .top)
                    }
                }
                .onChange(of: isLoading) { _, loading in
                    guard loading else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut) {
                        proxy.scrollTo(Self.stepAnchor, anchor: .top)
                    }
                }
                }
            }
            .navigationTitle(L("start.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("common.done")) { focusedField = nil }
                        .accessibilityIdentifier("keyboard.done")
                }
            }
        }
        .sheet(item: $timerRoute, onDismiss: presentPendingSavePrompt) { route in
            TimerView(session: route.session, step: route.step) { outcome, blocker, returnNote in
                handleTimerOutcome(outcome, session: route.session, step: route.step, blocker: blocker, returnNote: returnNote)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallReason)
                .environmentObject(env)
        }
        .sheet(item: $adminReaderInitialMode) { mode in
            AdminQuickReaderView(initialMode: mode)
                .environmentObject(env)
        }
        .sheet(isPresented: $showTemplates) {
            MicroTemplatePickerView(templates: MicroTemplateLibrary.templates(language: env.currentLanguage)) { template in
                apply(template)
            }
        }
        .sheet(isPresented: $showVault) {
            VaultPickerView(vault: env.vault) { item in
                useVaultItem(item)
            }
        }
        .sheet(item: $coStartRoute) { route in
            CoStartView(
                step: route.step,
                initialMode: route.initialMode,
                onFriendLimitReached: {
                    paywallReason = .friendCoStartLimit
                    coStartRoute = nil
                    showPaywall = true
                }
            )
                .environmentObject(env)
        }
        .sheet(item: $joinedCoStartRoute) { route in
            CoStartRoomView(
                room: route.room,
                stepText: route.stepText,
                isGuest: true,
                onLeave: {
                    await env.leaveCoStart(room: route.room, isGuest: true)
                    joinedCoStartRoute = nil
                }
            ) { outcome in
                Task { await env.endCoStartGuest(roomId: route.room.id, outcome: outcome) }
                joinedCoStartRoute = nil
            }
            .environmentObject(env)
        }
        .alert(
            L("savedStart.prompt.title"),
            isPresented: Binding(
                get: { savePrompt != nil },
                set: { isPresented in
                    if !isPresented { savePrompt = nil }
                }
            )
        ) {
            if let draft = savePrompt {
                Button(L("savedStart.prompt.save")) {
                    saveCompletedStart(draft)
                }
                .accessibilityIdentifier("savedStart.save")
            }
            Button(L("savedStart.prompt.notNow"), role: .cancel) {
                savePrompt = nil
            }
            .accessibilityIdentifier("savedStart.notNow")
        } message: {
            if let draft = savePrompt {
                Text(verbatim: L("savedStart.prompt.message", draft.title))
            }
        }
        .onChange(of: env.speech.transcript) { _, new in
            guard !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            inputText = new
            lastSource = .voice
            errorMessage = nil
        }
        .onChange(of: env.speech.lastError) { _, error in
            guard let error else { return }
            errorMessage = error.localizedDescription
        }
        .onChange(of: env.pendingCaptureText) { _, newValue in
            guard let newValue, !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            inputText = newValue
            lastSource = .manual
            currentStep = nil
            focusedField = .taskInput
            env.pendingCaptureText = nil
        }
        .onChange(of: env.pendingRescueRestart) { _, value in
            guard value else { return }
            runAutopilot()
            env.pendingRescueRestart = false
        }
        .onChange(of: env.pendingQuickAction) { _, value in
            guard let value else { return }
            handleQuickAction(value)
            env.pendingQuickAction = nil
        }
        .onAppear {
            refreshDailyOneThing()
#if DEBUG
            if ScreenshotMode.screen == .start, currentStep == nil {
                currentStep = env.createLocalNextStep(
                    proposal: ScreenshotDemoContent.mainStep,
                    sourceText: ScreenshotDemoContent.mainStep.step
                )
            }
#endif
        }
    }

    // MARK: - Subviews

    private var headerBand: some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            if !env.onboarding.firstName.isEmpty {
                Text(verbatim: L("start.greeting", env.onboarding.firstName))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("start.greeting")
            }
            Text(verbatim: L("start.subtitle"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let difficulty = env.onboarding.difficulty {
                Text(verbatim: L(difficulty.hintKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("start.difficultyHint")
            }
        }
        .padding(.horizontal, Theme.spacing16)
        .padding(.vertical, Theme.spacing4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryStartPanel: some View {
        VStack(spacing: Theme.spacing12) {
            voiceButton
            captureField
            stuckButton
        }
    }

    private func resumePanel(_ capsule: RecoveryCapsuleModel) -> some View {
        let context = env.resumeCardContext()
        return Button {
            resume(capsule)
        } label: {
            HStack(spacing: Theme.spacing10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L("start.kindStart.resume"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: context?.title ?? capsule.resumeTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(verbatim: context?.action ?? capsule.resumeStepText)
                        .font(.caption2)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    if let note = context?.returnNote {
                        Text(verbatim: L("returnNote.resume", note))
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            .padding(Theme.spacing12)
            .background(Theme.softAccent.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        }
        .pressableCard()
        .accessibilityIdentifier("start.kind.resume")
    }

    @ViewBuilder
    private var dailyOneThingPanel: some View {
        if let dailyOneThing {
            VStack(alignment: .leading, spacing: Theme.spacing10) {
                HStack {
                    SectionLabel("dailyOne.title")
                    Spacer()
                    Text(verbatim: L("dailyOne.source.\(dailyOneThing.source.rawValue)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: dailyOneThing.proposal.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                Text(verbatim: dailyOneThing.proposal.step)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                PrimaryButton("dailyOne.start", systemImage: "play.fill", accessibilityId: "dailyOne.start") {
                    currentStep = env.createDailyOneThingStep()
                    rescheduleMessage = L("dailyOne.loaded")
                }
                HStack(spacing: Theme.spacing12) {
                    Button(L("dailyOne.replace")) {
                        env.replaceDailyOneThing()
                        refreshDailyOneThing()
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .pressableCard()
                    .accessibilityIdentifier("dailyOne.replace")

                    Button(L("dailyOne.dismiss")) {
                        env.dismissDailyOneThing()
                        self.dailyOneThing = nil
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .pressableCard()
                    .accessibilityIdentifier("dailyOne.dismiss")
                }
            }
            .startKindCard()
            .accessibilityIdentifier("dailyOne.card")
        }
    }

    private func kindStartButton(_ key: String, systemImage: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.softAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                Text(verbatim: L(key))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .padding(Theme.spacing12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
        .pressableCard()
        .accessibilityLabel(Text(verbatim: L(key)))
        .accessibilityIdentifier(id)
    }

    private var moreWaysPanel: some View {
        DisclosureGroup(isExpanded: $moreWaysExpanded) {
            if moreWaysExpanded {
                VStack(alignment: .leading, spacing: Theme.spacing12) {
                    DisclosureGroup(isExpanded: $scanOrPasteExpanded) {
                        if scanOrPasteExpanded { scanOrPasteContent }
                    } label: {
                        moreWaysGroupLabel("start.moreWays.scan", systemImage: "doc.viewfinder", id: "start.moreWays.scan")
                    }

                    DisclosureGroup(isExpanded: $reuseStartExpanded) {
                        if reuseStartExpanded { reuseStartContent }
                    } label: {
                        moreWaysGroupLabel("start.moreWays.reuse", systemImage: "arrow.clockwise.circle", id: "start.moreWays.reuse")
                    }

                    DisclosureGroup(isExpanded: $coStartExpanded) {
                        if coStartExpanded { coStartContent }
                    } label: {
                        moreWaysGroupLabel("start.moreWays.costart", systemImage: "person.2.wave.2", id: "start.moreWays.costart")
                    }

                    DisclosureGroup(isExpanded: $matchFeelExpanded) {
                        if matchFeelExpanded { matchFeelContent }
                    } label: {
                        moreWaysGroupLabel("start.moreWays.match", systemImage: "heart.text.square", id: "start.moreWays.match")
                    }

                    DisclosureGroup(isExpanded: $planAheadExpanded) {
                        if planAheadExpanded { planAheadContent }
                    } label: {
                        moreWaysGroupLabel("start.moreWays.plan", systemImage: "list.bullet.clipboard", id: "start.moreWays.plan")
                    }
                }
                .padding(.top, Theme.spacing8)
            }
        } label: {
            Label(L("start.moreWays"), systemImage: moreWaysExpanded ? "chevron.up" : "chevron.right")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("start.moreWays")
        }
        .padding(.vertical, Theme.spacing12)
        .overlay(alignment: .top) { Divider().background(Theme.line) }
        .overlay(alignment: .bottom) { Divider().background(Theme.line) }
        .onChange(of: moreWaysExpanded) { _, expanded in
            guard !expanded else { return }
            scanOrPasteExpanded = false
            reuseStartExpanded = false
            coStartExpanded = false
            matchFeelExpanded = false
            planAheadExpanded = false
        }
    }

    private func moreWaysGroupLabel(_ key: String, systemImage: String, id: String) -> some View {
        Label(L(key), systemImage: systemImage)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
            .accessibilityIdentifier(id)
    }

    private var scanOrPasteContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                SectionLabel("start.kindStart.title")
                    .accessibilityIdentifier("start.kindStart")
                HStack(spacing: Theme.spacing8) {
                    kindStartButton("start.kindStart.admin", systemImage: "doc.text.magnifyingglass", id: "start.kind.admin") {
                        adminReaderInitialMode = .text
                    }
                    kindStartButton("start.kindStart.photo", systemImage: "camera.viewfinder", id: "start.kind.photo") {
                        adminReaderInitialMode = .photo
                    }
                }
            }
            if !env.isPlus {
                Text(verbatim: L("start.kindStart.adminLeft", env.usageState.adminQuickStartsRemaining))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            tinyAdminInboxField
        }
    }

    private var reuseStartContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                kindStartButton("template.open", systemImage: "square.grid.2x2.fill", id: "start.templates") {
                    showTemplates = true
                }
                kindStartButton("vault.open", systemImage: "tray.full.fill", id: "start.vault") {
                    showVault = true
                }
            }
            memoryAndScriptsPanel
        }
    }

    private var coStartContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            quickQuietCoStartButton
            quickFriendCoStartButton
            roomCodeJoinField
        }
    }

    private var matchFeelContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            categoryChips
            energyMatchChips
            frictionPresetChips
            frictionForecastPanel
            frictionMemoryPanel
            dayPartAndEmergencyPanel
        }
    }

    private var planAheadContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            if dailyOneThing != nil {
                dailyOneThingPanel
            }

            if let capsule = env.activeCapsule() {
                resumePanel(capsule)
            }

            if env.yesterdayRescueProposal() != nil {
                kindStartButton("yesterday.rescue.open", systemImage: "clock.arrow.circlepath", id: "start.yesterdayRescue") {
                    applyYesterdayRescue()
                }
            }

            kindStartButton("autopilot.open", systemImage: "sparkles", id: "start.autopilot") {
                runAutopilot()
            }
            .disabled(isLoading)

            calendarSoftLandingPanel
        }
    }

    private var voiceButton: some View {
        let voiceLabel = {
            if env.speech.isPreparing { return L("start.voice.preparing") }
            if env.speech.isListening { return L("start.voice.listening") }
            return L("start.voice.tap")
        }()

        return Button {
            toggleVoice()
        } label: {
            HStack(spacing: Theme.spacing12) {
                if env.speech.isPreparing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: env.speech.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(env.speech.isListening ? .white : Theme.accent)
                        .background(env.speech.isListening ? Color.red.opacity(0.82) : Theme.softAccent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                }
                Text(verbatim: voiceLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.trailing, Theme.spacing12)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)
            .background(env.speech.isListening ? Color.red.opacity(0.08) : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                    .stroke(env.speech.isListening ? Color.red.opacity(0.2) : Theme.line, lineWidth: 1)
            )
        }
        .pressableCard()
        .disabled(isLoading || env.speech.isPreparing)
        .accessibilityLabel(Text(verbatim: voiceLabel))
        .accessibilityValue(
            env.speech.isListening
                ? L("start.voice.listening")
                : (env.speech.isPreparing ? L("start.voice.preparing") : L("start.voice.tap"))
        )
        .accessibilityIdentifier("start.voice")
    }

    private var captureField: some View {
        FieldShell(systemImage: "text.alignleft") {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(verbatim: L("start.text.placeholder"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4, alignment: .leading)
                        .padding(.vertical, Theme.spacing10)
                        .allowsHitTesting(false)
                }
                TextField("", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4, alignment: .leading)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .taskInput)
                    .accessibilityLabel(Text(verbatim: L("start.text.placeholder")))
                    .accessibilityIdentifier("start.input")
                    .onChange(of: inputText) { _, _ in lastSource = .text }
                    .onSubmit { focusedField = nil }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)

                Button {
                    Task { await generate() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .background(hasCaptureInput || isLoading ? Theme.accent : Color.secondary.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                }
                .pressableCard()
            .disabled(!canSubmit)
            .accessibilityLabel(Text(verbatim: L("start.text.submit")))
            .accessibilityIdentifier("start.submit")
        }
    }

    private var stuckButton: some View {
        Button {
            handleStuck()
        } label: {
            Label(L("stuck.button"), systemImage: "lifepreserver.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                .background(Theme.softAccent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                        .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
                )
        }
        .pressableCard()
        .disabled(isLoading)
        .accessibilityIdentifier("global.stuck")
    }

    private var quickFriendCoStartButton: some View {
        Button {
            Task { await startFriendCoStart() }
        } label: {
            HStack(spacing: Theme.spacing12) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(canCoStart ? Theme.accent : Color.secondary)
                    .background(canCoStart ? Theme.softAccent : Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                Text(verbatim: L("costart.friend"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(canCoStart ? Theme.ink : Color.secondary)
                Spacer()
            }
            .padding(.horizontal, Theme.spacing12)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
        .pressableCard()
        .disabled(!canCoStart || isLoading)
        .accessibilityIdentifier("start.costart.friend")
    }

    private var quickQuietCoStartButton: some View {
        Button {
            Task { await startQuietCoStart() }
        } label: {
            HStack(spacing: Theme.spacing12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(canCoStart ? Theme.accent : Color.secondary)
                    .background(canCoStart ? Theme.softAccent : Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                Text(verbatim: L("costart.aiQuiet"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(canCoStart ? Theme.ink : Color.secondary)
                Spacer()
            }
            .padding(.horizontal, Theme.spacing12)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
        .pressableCard()
        .disabled(!canCoStart || isLoading)
        .accessibilityIdentifier("start.costart.quiet")
    }

    private var roomCodeJoinField: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("costart.joinByCode")
            FieldShell(systemImage: "number") {
                RoomCodeTextField(
                    text: $joinRoomCode,
                    placeholder: L("costart.code.placeholder"),
                    accessibilityIdentifier: "start.join.code",
                    isFocused: Binding(
                        get: { focusedField == .roomCode },
                        set: { isFocused in
                            if isFocused {
                                focusedField = .roomCode
                            } else if focusedField == .roomCode {
                                focusedField = nil
                            }
                        }
                    )
                )
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .focused($focusedField, equals: .roomCode)

                Button {
                    Task { await joinRoomByCode() }
                } label: {
                    Group {
                        // Joining is a round trip to the server; the arrow
                        // turning into a spinner is the only thing telling
                        // the person their tap went somewhere.
                        if isJoiningRoom {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .background(canJoinRoom || isJoiningRoom ? Theme.accent : Color.secondary.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                }
                .pressableCard()
                .disabled(!canJoinRoom)
                .accessibilityLabel(Text(verbatim: L("costart.join")))
                .accessibilityIdentifier("start.join.submit")
            }
            Text(verbatim: L("costart.code.hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tinyAdminInboxField: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("adminInbox.title")
            FieldShell(systemImage: "tray.and.arrow.down.fill") {
                TextField(L("adminInbox.placeholder"), text: $adminInboxText, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .adminInbox)
                    .onSubmit { focusedField = nil }
                    .accessibilityIdentifier("adminInbox.input")

                Button {
                    Task { await captureAdminInbox() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .background(canCaptureAdminInbox || isLoading ? Theme.accent : Color.secondary.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                }
                .pressableCard()
                .disabled(!canCaptureAdminInbox)
                .accessibilityIdentifier("adminInbox.submit")
            }
            Text(verbatim: L("adminInbox.hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("start.category.section")
            FlowChips(items: quickCategories, selected: $selectedCategory)
            if let selectedCategory {
                Label(L("start.category.selected", L(selectedCategory.localizationKey)), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("start.category.selected")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickCategories: [TaskCategory] {
        [.bills, .email, .appointments, .household, .workAdmin]
    }

    private var frictionForecastPanel: some View {
        Group {
            if let forecast = currentFrictionForecast {
                Button {
                    applyFrictionForecast()
                } label: {
                    HStack(alignment: .top, spacing: Theme.spacing12) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 36, height: 36)
                            .background(Theme.softAccent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                        VStack(alignment: .leading, spacing: Theme.spacing4) {
                            Text(verbatim: L("frictionForecast.title"))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.accent)
                            Text(verbatim: forecast.proposal.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: forecast.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Theme.spacing8)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(Theme.spacing12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.softAccent.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                            .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
                    )
                }
                .pressableCard()
                .accessibilityIdentifier("frictionForecast.apply")
            }
        }
    }

    private var currentFrictionForecast: FrictionForecast? {
        env.frictionForecast(text: inputText.trimmingCharacters(in: .whitespacesAndNewlines), category: selectedCategory)
    }

    private var energyMatchChips: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("energy.title")
            FlexibleHStack(spacing: Theme.spacing8) {
                ForEach(EnergyLevel.allCases) { energy in
                    Button {
                        selectedEnergy = selectedEnergy == energy ? nil : energy
                    } label: {
                        Text(verbatim: L("energy.\(energy.rawValue)"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, Theme.spacing12)
                            .padding(.vertical, Theme.spacing8)
                            .frame(minHeight: Theme.minTapTarget)
                            .background(selectedEnergy == energy ? Theme.softAccent : Theme.surfaceRaised)
                            .foregroundStyle(selectedEnergy == energy ? Theme.accent : Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                                    .stroke(selectedEnergy == energy ? Theme.accent.opacity(0.35) : Theme.line, lineWidth: 1)
                            )
                    }
                    .pressableCard()
                    .accessibilityIdentifier("energy.\(energy.rawValue)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var frictionPresetChips: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("frictionPreset.title")
            FlexibleHStack(spacing: Theme.spacing8) {
                ForEach(FrictionPreset.allCases) { preset in
                    Button {
                        applyFrictionPreset(preset)
                    } label: {
                        Label(L("frictionPreset.\(preset.rawValue)"), systemImage: frictionPresetIcon(preset))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, Theme.spacing10)
                            .padding(.vertical, Theme.spacing8)
                            .frame(minHeight: Theme.minTapTarget)
                            .background(Theme.surfaceRaised)
                            .foregroundStyle(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                    }
                    .pressableCard()
                    .accessibilityIdentifier("frictionPreset.\(preset.rawValue)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayPartAndEmergencyPanel: some View {
        HStack(spacing: Theme.spacing8) {
            kindStartButton("daypart.open", systemImage: "sun.max.fill", id: "start.daypart") {
                applyDayPart()
            }
            kindStartButton("emergency.open", systemImage: "bolt.heart.fill", id: "start.emergency") {
                applyEmergencyTiny()
            }
        }
    }

    private var memoryAndScriptsPanel: some View {
        VStack(alignment: .leading, spacing: Theme.spacing10) {
            SectionLabel("startScript.title")
                .accessibilityIdentifier("startScript.title")
            if let step = currentStep {
                QuietButton("startScript.save", systemImage: "bookmark.fill", accessibilityId: "startScript.save") {
                    env.saveStartScript(from: step)
                    proofMessage = L("startScript.saved")
                    vaultMessage = nil
                    rescheduleMessage = nil
                }
            }
            if env.startScripts.scripts.isEmpty {
                Text(verbatim: L("startScript.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(env.startScripts.recent(limit: 4)) { script in
                    Button {
                        applyStartScript(script)
                    } label: {
                        HStack(spacing: Theme.spacing10) {
                            Image(systemName: "bookmark")
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: script.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text(verbatim: script.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(Theme.spacing10)
                        .background(Theme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    }
                    .pressableCard()
                    .accessibilityIdentifier("startScript.item")
                }
            }
        }
        .startKindCard()
    }

    @ViewBuilder
    private var frictionMemoryPanel: some View {
        if let memory = env.frictionMemoryProposal(category: selectedCategory) {
            Button {
                applyFrictionMemory()
            } label: {
                Label(memory.title, systemImage: "brain.head.profile")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(Theme.spacing12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.softAccent.opacity(0.72))
                    .foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            }
            .pressableCard()
            .accessibilityIdentifier("frictionMemory.apply")
        }
    }

    private var calendarSoftLandingPanel: some View {
        VStack(alignment: .leading, spacing: Theme.spacing10) {
            SectionLabel("calendarSoft.title")
            FieldShell(systemImage: "calendar.badge.clock") {
                TextField(L("calendarSoft.placeholder"), text: $calendarEventTitle, axis: .vertical)
                    .lineLimit(1...2)
                    .submitLabel(.done)
                    .accessibilityIdentifier("calendarSoft.input")
                    .onSubmit { focusedField = nil }
                Button {
                    applyCalendarSoftLanding()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(canUseCalendarSoftLanding ? Theme.accent : Color.secondary.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                }
                .pressableCard()
                .disabled(!canUseCalendarSoftLanding)
                .accessibilityLabel(Text(verbatim: L("calendarSoft.submit")))
                .accessibilityIdentifier("calendarSoft.submit")
            }
            Stepper(L("calendarSoft.days", calendarDaysFromNow), value: $calendarDaysFromNow, in: 0...7)
                .font(.caption)
                .accessibilityIdentifier("calendarSoft.days")
            Text(verbatim: L("calendarSoft.hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .startKindCard()
    }

    private var usageLine: some View {
        Group {
            if !env.isPlus || env.proofOfStartCount > 0 {
                HStack(spacing: Theme.spacing8) {
                    Image(systemName: "bolt.heart")
                        .foregroundStyle(Theme.accent)
                    Text(verbatim: usageSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Theme.spacing12)
                .padding(.vertical, Theme.spacing8)
                .background(Theme.softAccent.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            }
        }
    }

    private var usageSummaryText: String {
        var parts: [String] = []
        if !env.isPlus {
            parts.append(L("usage.stepsLeft", env.usageState.stepsRemaining, env.usageState.stepsLimit))
        }
        if env.proofOfStartCount > 0 {
            parts.append(L("proof.count", env.proofOfStartCount))
        }
        return parts.joined(separator: "  ")
    }

    private func proofOfStartPanel(_ step: NextStepModel) -> some View {
        QuietButton("proof.started", systemImage: "checkmark.circle.fill", accessibilityId: "proof.started") {
            env.recordProofOfStart(step: step)
            proofMessage = L("proof.saved", env.proofOfStartCount)
            vaultMessage = nil
            rescheduleMessage = nil
        }
    }

    private var emptyHint: some View {
        HStack(alignment: .top, spacing: Theme.spacing12) {
            Image(systemName: "sparkle.magnifyingglass")
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(verbatim: L("start.empty.hint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warmWash.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line.opacity(0.7), lineWidth: 1)
        )
    }

    private var loadingState: some View {
        HStack(spacing: Theme.spacing12) {
            ProgressView()
                .tint(Theme.accent)
            Text(verbatim: L("capture.generating"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var hasCaptureInput: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategory != nil
    }

    private var canSubmit: Bool {
        hasCaptureInput && !isLoading
    }

    private var canCoStart: Bool {
        currentStep != nil || canSubmit
    }

    private var canJoinRoom: Bool {
        !isJoiningRoom && AppEnvironment.isValidRoomCode(joinRoomCode)
    }

    private var canCaptureAdminInbox: Bool {
        !adminInboxText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private var canUseCalendarSoftLanding: Bool {
        !calendarEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Actions

    private func refreshDailyOneThing() {
        dailyOneThing = env.dailyOneThingSelection()
    }

    private func toggleVoice() {
        if env.speech.isListening {
            env.speech.stop()
        } else {
            errorMessage = nil
            Task {
                do {
                    try await env.speech.start()
                    lastSource = .voice
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startFriendCoStart() async {
        await startCoStart(initialMode: .friendLink)
    }

    private func startQuietCoStart() async {
        await startCoStart(initialMode: .aiQuiet)
    }

    private func startCoStart(initialMode: CoStartRoomType) async {
        guard !isLoading else { return }
        focusedField = nil
        if let step = currentStep {
            coStartRoute = CoStartRoute(step: step, initialMode: initialMode)
            return
        }
        env.speech.stop()
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty || selectedCategory != nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            let step = try await env.generateNextStep(input: captureInput(raw: raw), energy: selectedEnergy)
            currentStep = step
            rescheduleMessage = nil
            vaultMessage = nil
            showPlan = false
            coStartRoute = CoStartRoute(step: step, initialMode: initialMode)
        } catch let usageError as UsageError {
            presentPaywall(for: usageError)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("common.error")
        }
        isLoading = false
    }

    private func generate() async {
        guard !isLoading else { return }
        env.speech.stop()
        focusedField = nil
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty || selectedCategory != nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            currentStep = try await env.generateNextStep(input: captureInput(raw: raw), energy: selectedEnergy)
            rescheduleMessage = nil
            vaultMessage = nil
            showPlan = false
        } catch let usageError as UsageError {
            presentPaywall(for: usageError)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("common.error")
        }
        isLoading = false
    }

    private func joinRoomByCode() async {
        guard !isJoiningRoom else { return }
        focusedField = nil
        let code = AppEnvironment.normalizedRoomCode(joinRoomCode)
        guard AppEnvironment.isValidRoomCode(code) else { return }
        isJoiningRoom = true
        errorMessage = nil
        let guestStep = L("costart.defaultGuestStep")
        do {
            let room = try await env.joinCoStartRoom(
                code: code,
                stepText: guestStep,
                displayName: env.preferredGuestDisplayName
            )
            if let room {
                joinedCoStartRoute = JoinedCoStartRoute(room: room, stepText: guestStep)
                joinRoomCode = ""
            } else {
                errorMessage = L("costart.roomNotFound")
            }
        } catch {
            errorMessage = L("common.error")
        }
        isJoiningRoom = false
    }

    private func captureInput(raw: String) -> CaptureInput {
        let text = raw.isEmpty ? (selectedCategory?.displayName ?? "") : raw
        let source: CaptureSource = raw.isEmpty ? .manual : lastSource
        return CaptureInput(
            rawText: text,
            source: source,
            preferredCategory: selectedCategory,
            language: env.currentLanguage
        )
    }

    private func presentPaywall(for error: Error) {
        guard let trigger = PaywallTrigger.fromReturnedLimitError(error) else {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("common.error")
            return
        }
        paywallReason = trigger
        showPaywall = true
    }

    private func startTimer(for step: NextStepModel) {
        let minutes = min(step.proposal.timerMinutes, 25)
        env.recordProofOfStart(step: step)
        let session = env.startTimer(step: step, minutes: minutes)
        timerRoute = TimerRoute(session: session, step: step)
    }

    private func resume(_ capsule: RecoveryCapsuleModel) {
        let proposal = capsule.resumeProposal
        let step = env.persistence.saveNextStep(proposal: proposal, capture: nil, taskTitle: proposal.title)
        currentStep = step
        let session = env.startTimer(step: step, minutes: min(proposal.timerMinutes, 25))
        timerRoute = TimerRoute(session: session, step: step)
    }

    private func apply(_ template: MicroTemplate) {
        currentStep = env.createLocalNextStep(
            proposal: template.proposal,
            sourceText: L(template.titleKey),
            source: .manual
        )
        inputText = ""
        selectedCategory = template.proposal.category
        rescheduleMessage = L("template.applied")
        vaultMessage = nil
        showPlan = false
        showTemplates = false
    }

    private func useVaultItem(_ item: VaultItem) {
        let category = item.category ?? .other
        let proposal = NextStepProposal(
            title: item.title,
            step: item.body,
            timerMinutes: 5,
            stopCondition: L("vault.stop"),
            category: category,
            shrinkLevel: .one,
            whyThisStep: L("vault.why")
        )
        currentStep = env.createLocalNextStep(proposal: proposal, sourceText: item.body, source: .manual)
        inputText = ""
        selectedCategory = category
        rescheduleMessage = L("vault.applied")
        vaultMessage = nil
        showPlan = false
        showVault = false
    }

    private func runAutopilot() {
        focusedField = nil
        let step = env.createAutopilotStep()
        currentStep = step
        inputText = ""
        selectedCategory = step.category
        rescheduleMessage = L("autopilot.loaded")
        vaultMessage = nil
        showPlan = false
    }

    private func applyYesterdayRescue() {
        focusedField = nil
        guard let step = env.createYesterdayRescueStep() else {
            applyEmergencyTiny()
            return
        }
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("yesterday.rescue.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func applyDayPart() {
        focusedField = nil
        let step = env.createDayPartStep()
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("daypart.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func applyEmergencyTiny() {
        focusedField = nil
        let step = env.createEmergencyTinyStep()
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("emergency.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func applyFrictionMemory() {
        focusedField = nil
        guard let step = env.createFrictionMemoryStep(category: selectedCategory) else { return }
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("frictionMemory.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func applyFrictionForecast() {
        focusedField = nil
        guard let step = env.createFrictionForecastStep(
            text: inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory
        ) else { return }
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("frictionForecast.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func applyStartScript(_ script: StartScript) {
        focusedField = nil
        let step = env.createStartScriptStep(script)
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("startScript.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func applyCalendarSoftLanding() {
        focusedField = nil
        let title = calendarEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard let step = env.createCalendarSoftLandingStep(title: title, daysFromNow: calendarDaysFromNow) else {
            errorMessage = L("calendarSoft.noMatch")
            return
        }
        currentStep = nil
        currentStep = step
        selectedCategory = step.category
        calendarEventTitle = ""
        rescheduleMessage = L("calendarSoft.loaded")
        vaultMessage = nil
        proofMessage = nil
        errorMessage = nil
        showPlan = false
    }

    private func handleQuickAction(_ kind: QuickActionKind) {
        switch kind {
        case .emergencyTiny:
            applyEmergencyTiny()
        case .stuck:
            handleStuck()
        case .startFive:
            if let proposal = kind.proposal(language: env.currentLanguage) {
                currentStep = env.createLocalNextStep(proposal: proposal, sourceText: L("quickAction.source"), source: .manual)
                selectedCategory = currentStep?.category
                rescheduleMessage = L("quickAction.loaded")
            }
        case .rescueYesterday:
            applyYesterdayRescue()
        case .pasteAdmin:
            focusedField = .adminInbox
        }
    }

    private func applyFrictionPreset(_ preset: FrictionPreset) {
        focusedField = nil
        let step = env.createFrictionPresetStep(preset, category: selectedCategory)
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("frictionPreset.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func handleStuck() {
        focusedField = nil
        if let currentStep, rootProposalBeforeShrink == nil {
            rootProposalBeforeShrink = currentStep.proposal
        }
        let step = env.createStuckStep(current: currentStep)
        currentStep = step
        selectedCategory = step.category
        rescheduleMessage = L("stuck.loaded")
        vaultMessage = nil
        proofMessage = nil
        showPlan = false
    }

    private func captureAdminInbox() async {
        guard !isLoading else { return }
        focusedField = nil
        let raw = adminInboxText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let step = try await env.captureAdminInbox(text: raw)
            currentStep = step
            selectedCategory = step.category
            adminInboxText = ""
            rescheduleMessage = L("adminInbox.saved")
            vaultMessage = nil
            proofMessage = nil
            showPlan = false
        } catch let usageError as UsageError {
            presentPaywall(for: usageError)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("common.error")
        }
        isLoading = false
    }

    private func frictionPresetIcon(_ preset: FrictionPreset) -> String {
        switch preset {
        case .needLogin: return "key.fill"
        case .needDocument: return "doc.fill"
        case .tooVague: return "questionmark.circle.fill"
        case .tooManyTabs: return "rectangle.stack.fill"
        case .needAnotherPerson: return "person.2.fill"
        }
    }

    private func shrink(_ step: NextStepModel) {
        if rootProposalBeforeShrink == nil {
            rootProposalBeforeShrink = step.proposal
        }
        // shrinkCurrentStep persists the new level onto step, so the previous
        // level comparison here was always true.
        env.shrinkCurrentStep(step)
        rescheduleMessage = nil
    }

    private func skip(_ step: NextStepModel) {
        let result = env.rescheduleStep(step, reason: .skipped)
        rescheduleMessage = result.message
    }

    private func handleTimerOutcome(_ outcome: TimerOutcome, session: TimerSessionModel, step: NextStepModel, blocker: BlockerReason? = nil, returnNote: String? = nil) {
        let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
        if outcome == .completed {
            let completedProposal = step.proposal
            env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step, blocker: blocker, returnNote: returnNote)
            timerRoute = nil
            if let rootProposalBeforeShrink,
               env.reopenNextLargerStep(step, rootProposal: rootProposalBeforeShrink) != nil {
                currentStep = step
                rescheduleMessage = L("stuck.rungCompleted")
                proofMessage = nil
                vaultMessage = nil
                showPlan = false
                return
            }
            withAnimation(reduceMotion ? nil : .default) {
                currentStep = nil
                inputText = ""
                selectedCategory = nil
                rescheduleMessage = nil
                vaultMessage = nil
            }
            rootProposalBeforeShrink = nil
            pendingSaveStart = SavedStartCompletionPolicy.draft(
                outcome: outcome,
                isRootFinished: true,
                proposal: completedProposal,
                vault: env.vault
            )
        } else if outcome == .partial || outcome == .paused {
            let result = env.rescheduleStep(step, reason: .paused)
            env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step, blocker: blocker, returnNote: returnNote)
            timerRoute = nil
            rescheduleMessage = result.message
        } else {
            let result = env.rescheduleStep(step, reason: .skipped)
            env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step, blocker: blocker, returnNote: returnNote)
            timerRoute = nil
            rescheduleMessage = result.message
        }
    }

    private func presentPendingSavePrompt() {
        guard let pendingSaveStart else { return }
        self.pendingSaveStart = nil
        savePrompt = pendingSaveStart
    }

    private func saveCompletedStart(_ draft: SavedStartDraft) {
        env.vault.add(title: draft.title, body: draft.body, category: draft.category)
        savePrompt = nil
        savedStartConfirmation = draft
    }
}

// MARK: - FlowChips

struct FlowChips: View {
    let items: [TaskCategory]
    @Binding var selected: TaskCategory?

    var body: some View {
        FlexibleHStack(spacing: Theme.spacing8) {
            ForEach(items) { item in
                Button {
                    selected = (selected == item) ? nil : item
                } label: {
                    Label {
                        Text(verbatim: L(item.localizationKey))
                    } icon: {
                        Image(systemName: selected == item ? "checkmark.circle.fill" : item.systemImage)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, Theme.spacing12)
                    .padding(.vertical, Theme.spacing8)
                    .frame(minHeight: Theme.minTapTarget)
                    .background(selected == item ? Theme.softAccent : Theme.surfaceRaised)
                    .foregroundStyle(selected == item ? Theme.accent : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                            .stroke(selected == item ? Theme.accent.opacity(0.35) : Theme.line, lineWidth: 1)
                    )
                }
                .pressableCard()
                .accessibilityLabel(Text(verbatim: L(item.localizationKey)))
                .accessibilityAddTraits(selected == item ? .isSelected : [])
            }
        }
    }
}

/// A simple wrapping HStack that lays out children in a flow.
struct FlexibleHStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: spacing) { content() }
    }
}

/// Flow layout for chips. Uses iOS 16+ Layout protocol.
///
/// Sizing and placement share one row calculation so the reported height always
/// matches what is drawn, and each row is as tall as its tallest chip.
struct FlowLayout: Layout {
    let spacing: CGFloat

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && width > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = width
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let laidOut = rows(for: subviews, maxWidth: proposal.width ?? .infinity)
        let height = laidOut.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, laidOut.count - 1))
        // Never report an infinite width: an unspecified proposal should resolve
        // to the widest row, not to the proposal itself.
        let width = proposal.width ?? laidOut.map(\.width).max() ?? 0
        return CGSize(width: width, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
}

struct MicroTemplatePickerView: View {
    let templates: [MicroTemplate]
    let onSelect: (MicroTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    Button {
                        onSelect(template)
                    } label: {
                        HStack(spacing: Theme.spacing12) {
                            Image(systemName: template.systemImage)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: Theme.spacing4) {
                                Text(verbatim: L(template.titleKey))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.ink)
                                Text(verbatim: L(template.subtitleKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("template.\(template.id)")
                }
            }
            .navigationTitle(L("template.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}

struct VaultPickerView: View {
    @ObservedObject var vault: PersonalVaultStore
    let onUse: (VaultItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        NavigationStack {
            Group {
                if vault.items.isEmpty {
                    ContentUnavailableView(
                        L("vault.empty.title"),
                        systemImage: "tray",
                        description: Text(verbatim: L("vault.empty.body"))
                    )
                } else {
                    List {
                        ForEach(vault.items) { item in
                            Button {
                                onUse(item)
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.spacing4) {
                                    Text(verbatim: item.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.ink)
                                    Text(verbatim: item.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    if let category = item.category {
                                        Label(L(category.localizationKey), systemImage: category.systemImage)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                            .accessibilityIdentifier("vault.item")
                            .swipeActions {
                                Button(L("common.delete"), role: .destructive) {
                                    vault.delete(item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("vault.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}
