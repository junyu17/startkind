import SwiftUI
import Combine

struct TimerView: View {
    let session: TimerSessionModel
    let step: NextStepModel
    let onOutcome: (TimerOutcome, BlockerReason?, String?) -> Void

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var remaining: Int
    @State private var isPaused = false
    @State private var showBlockerPicker = false
    @State private var pendingOutcome: TimerOutcome = .paused

    private let totalSeconds: Int

    init(session: TimerSessionModel, step: NextStepModel, onOutcome: @escaping (TimerOutcome, BlockerReason?, String?) -> Void) {
        self.session = session
        self.step = step
        self.onOutcome = onOutcome
        let secs = session.plannedMinutes * 60
        _remaining = State(initialValue: secs)
        totalSeconds = secs
    }

    private var proposal: NextStepProposal { step.proposal }
    private var timeIsUp: Bool { remaining <= 0 }

    var body: some View {
        VStack(spacing: Theme.spacing24) {
            Text(verbatim: L(timeIsUp ? "timer.finished.title" : "timer.title"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.spacing16)

            VStack(spacing: Theme.spacing4) {
                Text(verbatim: proposal.title)
                    .font(.headline)
                Text(verbatim: proposal.step)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)

            Text(verbatim: L("timer.stopHint", proposal.stopCondition))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Text(verbatim: timeString(remaining))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeIsUp ? Theme.accent : .primary)
                .accessibilityLabel(Text(verbatim: timeString(remaining)))

            if isPaused && !timeIsUp {
                Text(verbatim: L("timer.paused"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: Theme.spacing12) {
                if timeIsUp {
                    Text(verbatim: L("timer.finished.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                PrimaryButton("timer.done", systemImage: "checkmark.circle.fill", accessibilityId: "timer.done") {
                    onOutcome(.completed, nil, nil)
                }
                HStack(spacing: Theme.spacing12) {
                    QuietButton("timer.continueFive", systemImage: "plus", accessibilityId: "timer.continue5") {
                        remaining += 300
                    }
                    QuietButton("timer.makeSmaller", systemImage: "arrow.down.right", accessibilityId: "timer.makesmaller") {
                        askBlocker(for: .paused)
                    }
                }
                if !timeIsUp {
                    QuietButton("timer.interrupted", systemImage: "pause.circle", accessibilityId: "timer.interrupted") {
                        askBlocker(for: .paused)
                    }
                    Button {
                        isPaused.toggle()
                    } label: {
                        Text(verbatim: L(isPaused ? "timer.resume" : "timer.pause"))
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.bottom, Theme.spacing24)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !isPaused, remaining > 0 else { return }
            remaining -= 1
        }
        .sheet(isPresented: $showBlockerPicker) {
            BlockerPickerView(
                titleKey: pendingOutcome == .abandoned ? "blocker.title.skip" : "blocker.title.pause",
                onSelect: { blocker, note in
                    showBlockerPicker = false
                    onOutcome(pendingOutcome, blocker, note)
                },
                onSkip: { note in
                    showBlockerPicker = false
                    onOutcome(pendingOutcome, nil, note)
                }
            )
        }
    }

    private func askBlocker(for outcome: TimerOutcome) {
        pendingOutcome = outcome
        showBlockerPicker = true
    }

    private func timeString(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct BlockerPickerView: View {
    let titleKey: String
    let onSelect: (BlockerReason, String?) -> Void
    let onSkip: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    @State private var returnNote = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.spacing16) {
                Text(verbatim: L("blocker.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    SectionLabel("returnNote.title")
                    TextField(L("returnNote.placeholder"), text: $returnNote, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("returnNote.input")
                    Text(verbatim: L("returnNote.hint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: Theme.spacing8) {
                    ForEach(BlockerReason.allCases) { reason in
                        Button {
                            onSelect(reason, cleanNote)
                        } label: {
                            HStack(spacing: Theme.spacing12) {
                                Image(systemName: reason.systemImage)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 24)
                                Text(verbatim: L(reason.localizationKey))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                            .padding(.horizontal, Theme.spacing12)
                            .background(Theme.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("blocker.\(reason.rawValue)")
                    }
                }

                Button {
                    onSkip(cleanNote)
                } label: {
                    Text(verbatim: L("blocker.skip"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("blocker.skip")

                Spacer()
            }
            .padding(Theme.spacing16)
            .navigationTitle(L(titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var cleanNote: String? {
        let trimmed = returnNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
