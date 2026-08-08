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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing20) {
                    Text(verbatim: L("start.subtitle"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    voiceButton
                    captureField
                    categoryChips
                    usageLine

                    if isLoading {
                        ProgressView()
                            .padding(.vertical, Theme.spacing24)
                        Text(verbatim: L("capture.generating"))
                            .foregroundStyle(.secondary)
                    } else if let step = currentStep {
                        NextStepCard(
                            step: step,
                            showPlan: $showPlan,
                            onStart: { startTimer(for: step) },
                            onShrink: { shrink(step) },
                            onSkip: { skip(step) },
                            onCoStart: { currentStep = step; showCoStart = true }
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
                .padding()
                .animation(.easeInOut, value: rescheduleMessage)
            }
            .navigationTitle(L("start.title"))
            .navigationBarTitleDisplayMode(.large)
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
                CoStartView(step: step)
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

    private var voiceButton: some View {
        Button {
            toggleVoice()
        } label: {
            VStack(spacing: Theme.spacing8) {
                Image(systemName: env.speech.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.white)
                    .background(env.speech.isListening ? Color.red.opacity(0.8) : Theme.accent)
                    .clipShape(Circle())
                Text(verbatim: L(env.speech.isListening ? "start.voice.listening" : "start.voice.tap"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(verbatim: L(env.speech.isListening ? "start.voice.listening" : "start.voice.tap")))
        .accessibilityIdentifier("start.voice")
    }

    private var captureField: some View {
        HStack(spacing: Theme.spacing8) {
            TextField(L("start.text.placeholder"), text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .accessibilityIdentifier("start.input")
                .onChange(of: inputText) { _, _ in lastSource = .text }
            PrimaryButton("start.text.submit", systemImage: "arrow.up.circle.fill", enabled: !inputText.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategory != nil, accessibilityId: "start.submit") {
                Task { await generate() }
            }
            .frame(width: 120)
        }
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: L("start.category.section"))
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowChips(items: quickCategories, selected: $selectedCategory)
        }
    }

    private var quickCategories: [TaskCategory] {
        [.bills, .email, .appointments, .household, .workAdmin]
    }

    private var usageLine: some View {
        Group {
            if !env.isPlus {
                Text(verbatim: L("usage.stepsLeft", env.usageState.stepsRemaining, env.usageState.stepsLimit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyHint: some View {
        Text(verbatim: L("start.empty.hint"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.spacing24)
    }

    // MARK: - Actions

    private func toggleVoice() {
        if env.speech.isListening {
            env.speech.stop()
        } else {
            do {
                try env.speech.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
        let text = raw.isEmpty ? (selectedCategory?.displayName ?? "") : raw
        let source: CaptureSource = raw.isEmpty ? .manual : lastSource
        let input = CaptureInput(
            rawText: text,
            source: source,
            preferredCategory: selectedCategory,
            language: env.currentLanguage
        )
        do {
            currentStep = try await env.generateNextStep(input: input)
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
                    .background(selected == item ? Theme.accent.opacity(0.18) : Color(.tertiarySystemBackground))
                    .foregroundStyle(selected == item ? Theme.accent : .primary)
                    .clipShape(Capsule())
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
