import SwiftUI
import Combine

struct TimerView: View {
    let session: TimerSessionModel
    let step: NextStepModel
    let onOutcome: (TimerOutcome) -> Void

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var remaining: Int
    @State private var isPaused = false

    private let totalSeconds: Int

    init(session: TimerSessionModel, step: NextStepModel, onOutcome: @escaping (TimerOutcome) -> Void) {
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
                    onOutcome(.completed)
                }
                HStack(spacing: Theme.spacing12) {
                    QuietButton("timer.continueFive", systemImage: "plus", accessibilityId: "timer.continue5") {
                        remaining += 300
                    }
                    QuietButton("timer.makeSmaller", systemImage: "arrow.down.right", accessibilityId: "timer.makesmaller") {
                        onOutcome(.paused)
                    }
                }
                if !timeIsUp {
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
    }

    private func timeString(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
