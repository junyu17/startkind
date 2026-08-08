import SwiftUI

struct StartView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager

    @State private var inputText = ""
    @State private var lastSource: CaptureSource = .text
    @State private var selectedCategory: TaskCategory?
    @State private var currentStep: NextStepModel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var rescheduleMessage: String?
    @State private var showPlan = false

    @State private var showPaywall = false
    @State private var paywallReason: PaywallTrigger = .stepLimit

    @State private var timerSession: TimerSessionModel?
    @State private var showCoStart = false
    @State private var coStartInitialMode: CoStartRoomType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    headerBand
                    composerPanel
                    categoryChips
                    usageLine

                    if isLoading {
                        loadingState
                    } else if let step = currentStep {
                        NextStepCard(
                            step: step,
                            showPlan: $showPlan,
                            onStart: { startTimer(for: step) },
                            onShrink: { shrink(step) },
                            onSkip: { skip(step) },
                            onCoStart: {
                                currentStep = step
                                coStartInitialMode = nil
                                showCoStart = true
                            }
                        )
                    } else {
                        emptyHint
                    }

                    if let rescheduleMessage {
                        KindBanner(text: rescheduleMessage)
                            .transition(.opacity)
                    }
                    if let errorMessage {
                        Text(verbatim: errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, Theme.spacing16)
                .padding(.vertical, Theme.spacing16)
                .animation(.easeInOut, value: rescheduleMessage)
            }
            .navigationTitle(L("start.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
        }
        .sheet(item: $timerSession) { session in
            if let step = currentStep {
                TimerView(session: session, step: step) { outcome in
                    handleTimerOutcome(outcome, session: session, step: step)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallReason)
                .environmentObject(env)
        }
        .sheet(isPresented: $showCoStart) {
            if let step = currentStep {
                CoStartView(step: step, initialMode: coStartInitialMode)
                    .environmentObject(env)
            }
        }
        .onChange(of: env.speech.transcript) { _, new in
            if env.speech.isListening {
                inputText = new
                lastSource = .voice
            }
        }
    }

    // MARK: - Subviews

    private var headerBand: some View {
        HStack(alignment: .center, spacing: Theme.spacing12) {
            VStack(alignment: .leading, spacing: Theme.spacing4) {
                SectionLabel("start.title")
                Text(verbatim: L("start.subtitle"))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.spacing12)
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.softAccent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        }
        .padding(Theme.spacing16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var composerPanel: some View {
        VStack(spacing: Theme.spacing12) {
            voiceButton
            captureField
            quickFriendCoStartButton
        }
        .startKindCard()
    }

    private var voiceButton: some View {
        Button {
            toggleVoice()
        } label: {
            HStack(spacing: Theme.spacing12) {
                Image(systemName: env.speech.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(env.speech.isListening ? .white : Theme.accent)
                    .background(env.speech.isListening ? Color.red.opacity(0.82) : Theme.softAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                Text(verbatim: L(env.speech.isListening ? "start.voice.listening" : "start.voice.tap"))
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
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: L(env.speech.isListening ? "start.voice.listening" : "start.voice.tap")))
        .accessibilityIdentifier("start.voice")
    }

    private var captureField: some View {
        FieldShell(systemImage: "text.alignleft") {
            TextField(L("start.text.placeholder"), text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.done)
                .accessibilityIdentifier("start.input")
                .onChange(of: inputText) { _, _ in lastSource = .text }

            Button {
                Task { await generate() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(canSubmit ? Theme.accent : Color.secondary.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .accessibilityLabel(Text(verbatim: L("start.text.submit")))
            .accessibilityIdentifier("start.submit")
        }
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
        .buttonStyle(.plain)
        .disabled(!canCoStart || isLoading)
        .accessibilityIdentifier("start.costart.friend")
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            SectionLabel("start.category.section")
            FlowChips(items: quickCategories, selected: $selectedCategory)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickCategories: [TaskCategory] {
        [.bills, .email, .appointments, .household, .workAdmin]
    }

    private var usageLine: some View {
        Group {
            if !env.isPlus {
                HStack(spacing: Theme.spacing8) {
                    Image(systemName: "bolt.heart")
                        .foregroundStyle(Theme.accent)
                    Text(verbatim: L("usage.stepsLeft", env.usageState.stepsRemaining, env.usageState.stepsLimit))
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

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategory != nil
    }

    private var canCoStart: Bool {
        currentStep != nil || canSubmit
    }

    // MARK: - Actions

    private func toggleVoice() {
        if env.speech.isListening {
            env.speech.stop()
        } else {
            Task {
                do {
                    try await env.speech.start()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startFriendCoStart() async {
        if let step = currentStep {
            coStartInitialMode = .friendLink
            currentStep = step
            showCoStart = true
            return
        }
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty || selectedCategory != nil else { return }
        guard env.canGenerateStep else {
            paywallReason = .stepLimit
            showPaywall = true
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let step = try await env.generateNextStep(input: captureInput(raw: raw))
            currentStep = step
            rescheduleMessage = nil
            showPlan = false
            coStartInitialMode = .friendLink
            showCoStart = true
        } catch let usageError as UsageError {
            switch usageError {
            case .stepLimitReached: paywallReason = .stepLimit
            case .adminLimitReached: paywallReason = .adminLimit
            }
            showPaywall = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("common.error")
        }
        isLoading = false
    }

    private func generate() async {
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty || selectedCategory != nil else { return }
        guard env.canGenerateStep else {
            paywallReason = .stepLimit
            showPaywall = true
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            currentStep = try await env.generateNextStep(input: captureInput(raw: raw))
            rescheduleMessage = nil
            showPlan = false
        } catch let usageError as UsageError {
            switch usageError {
            case .stepLimitReached: paywallReason = .stepLimit
            case .adminLimitReached: paywallReason = .adminLimit
            }
            showPaywall = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("common.error")
        }
        isLoading = false
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

    private func startTimer(for step: NextStepModel) {
        let minutes = min(step.proposal.timerMinutes, 25)
        timerSession = env.startTimer(step: step, minutes: minutes)
    }

    private func shrink(_ step: NextStepModel) {
        let proposal = env.shrinkCurrentStep(step)
        if proposal.shrinkLevel == step.shrinkLevel {
            rescheduleMessage = nil
        }
    }

    private func skip(_ step: NextStepModel) {
        let result = env.rescheduleStep(step, reason: .skipped)
        rescheduleMessage = result.message
    }

    private func handleTimerOutcome(_ outcome: TimerOutcome, session: TimerSessionModel, step: NextStepModel) {
        let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
        if outcome == .completed {
            env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step)
            timerSession = nil
            withAnimation {
                currentStep = nil
                inputText = ""
                selectedCategory = nil
                rescheduleMessage = nil
            }
        } else if outcome == .partial || outcome == .paused {
            let result = env.rescheduleStep(step, reason: .paused)
            env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step)
            timerSession = nil
            rescheduleMessage = result.message
        } else {
            let result = env.rescheduleStep(step, reason: .skipped)
            env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step)
            timerSession = nil
            rescheduleMessage = result.message
        }
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
                        Image(systemName: item.systemImage)
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
                .buttonStyle(.plain)
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
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([subview])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                rowWidth += size.width + spacing
            }
        }
        let height = rows.reduce(0) { $0 + ($1.first?.sizeThatFits(.unspecified).height ?? 0) + spacing } - spacing
        return CGSize(width: maxWidth, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
