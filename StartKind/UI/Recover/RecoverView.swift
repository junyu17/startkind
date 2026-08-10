import SwiftUI

struct RecoverView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @State private var capsule: RecoveryCapsuleModel?
    @State private var session: TimerSessionModel?
    @State private var showTimer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing20) {
                    if let capsule {
                        capsuleCard(capsule)
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle(L("recover.title"))
            .background(Theme.background.ignoresSafeArea())
        }
        .onAppear { capsule = env.activeCapsule() }
        .sheet(isPresented: $showTimer) {
            if let session, let step = env.persistence.fetchNextStep(id: session.nextStepId ?? UUID()) {
                TimerView(session: session, step: step) { outcome, blocker, returnNote in
                    let elapsed = max(0, Int(Date.now.timeIntervalSince(session.createdAt)))
                    if outcome == .partial || outcome == .paused {
                        _ = env.rescheduleStep(step, reason: .paused)
                    } else if outcome == .abandoned {
                        _ = env.rescheduleStep(step, reason: .skipped)
                    }
                    env.finishTimer(session: session, actualSeconds: elapsed, outcome: outcome, step: step, blocker: blocker, returnNote: returnNote)
                    showTimer = false
                    if outcome == .completed { capsule = nil }
                }
            }
        }
    }

    private func capsuleCard(_ model: RecoveryCapsuleModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            Text(verbatim: L("recover.lastStep"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: model.resumeTitle)
                .font(.title3)
                .fontWeight(.bold)
            Text(verbatim: model.resumeStepText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: Theme.spacing4) {
                Image(systemName: "flag.checkered").foregroundStyle(.secondary).font(.caption)
                Text(verbatim: model.resumeStopCondition)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if let link = model.relatedLink, !link.isEmpty {
                Text(verbatim: L("recover.related") + ": " + link)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let blocker = model.blockerReason {
                Label(L("recover.blocker", L(blocker.localizationKey)), systemImage: blocker.systemImage)
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .padding(.vertical, Theme.spacing4)
                    .accessibilityIdentifier("recover.blocker")
            }

            if let note = model.returnNote {
                Label(note, systemImage: "note.text")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.spacing4)
                    .accessibilityIdentifier("recover.returnNote")
            }

            PrimaryButton("recover.startTimer", systemImage: "play.fill") {
                resume(from: model)
            }
            QuietButton("recover.clear", systemImage: "trash") {
                env.clearActiveCapsule()
                capsule = nil
            }
        }
        .startKindCard()
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(verbatim: L("recover.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing40)
    }

    private func resume(from capsule: RecoveryCapsuleModel) {
        let proposal = capsule.resumeProposal
        let step = env.persistence.saveNextStep(proposal: proposal, capture: nil, taskTitle: proposal.title)
        session = env.startTimer(step: step, minutes: min(proposal.timerMinutes, 25))
        showTimer = true
    }
}
