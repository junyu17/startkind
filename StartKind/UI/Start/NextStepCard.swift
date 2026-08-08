import SwiftUI

struct NextStepCard: View {
    let step: NextStepModel
    @Binding var showPlan: Bool
    let onStart: () -> Void
    let onShrink: () -> Void
    let onSkip: () -> Void
    var onCoStart: () -> Void = {}
    @EnvironmentObject private var loc: LocalizationManager

    private var proposal: NextStepProposal { step.proposal }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            headerRow

            Text(verbatim: proposal.title)
                .font(.title3)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: proposal.step)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            stopRow

            if showPlan, let why = proposal.whyThisStep {
                Text(verbatim: why)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(
                verbatim: L("nextstep.timer.label") + " " + L("nextstep.timer.minutes", proposal.timerMinutes),
                systemImage: "play.fill",
                accessibilityId: "nextstep.start"
            ) {
                onStart()
            }

            HStack(spacing: Theme.spacing8) {
                QuietButton("nextstep.makeSmaller", systemImage: "arrow.down.right") {
                    onShrink()
                }
                .disabled(proposal.shrinkLevel == .three)

                Button {
                    withAnimation { showPlan.toggle() }
                } label: {
                    Text(verbatim: L(showPlan ? "nextstep.hidePlan" : "nextstep.showPlan"))
                        .font(.footnote)
                        .frame(minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.plain)
                .disabled(proposal.whyThisStep == nil)
            }

            QuietButton("costart.cta", systemImage: "person.2.wave.2", accessibilityId: "nextstep.costart") {
                onCoStart()
            }

            Button(role: .cancel) {
                onSkip()
            } label: {
                Text(verbatim: L("timer.outcome.skipped"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
            .buttonStyle(.plain)
        }
        .startKindCard()
    }

    private var headerRow: some View {
        HStack(spacing: Theme.spacing8) {
            Label {
                Text(verbatim: L(proposal.category.localizationKey))
                    .font(.caption)
            } icon: {
                Image(systemName: proposal.category.systemImage)
            }
            .foregroundStyle(Theme.accent)

            Spacer()

            if proposal.shrinkLevel != .zero {
                Text(verbatim: L("nextstep.shrink.level"))
                    .font(.caption2)
                    .padding(.horizontal, Theme.spacing8)
                    .padding(.vertical, Theme.spacing4)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var stopRow: some View {
        HStack(alignment: .top, spacing: Theme.spacing4) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(verbatim: proposal.stopCondition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
