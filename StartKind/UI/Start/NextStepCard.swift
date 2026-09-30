import SwiftUI

struct NextStepCard: View {
    let step: NextStepModel
    @Binding var showPlan: Bool
    let onStart: () -> Void
    let onShrink: () -> Void
    let onSkip: () -> Void
    var actionPrep: ActionPrepPlan?
    var onPrepare: (ActionPrepPlan) -> Void = { _ in }
    var onUseStartLadder: (Int) -> Void = { _ in }
    var onCoStart: () -> Void = {}
    var onSaveToVault: () -> Void = {}
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moreActionsExpanded = false

    private var proposal: NextStepProposal { step.proposal }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            headerRow

            Text(verbatim: proposal.title)
                .font(.title3)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("nextstep.title")

            Text(verbatim: proposal.step)
                .font(.body)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nextstep.action")

            stopRow

            PrimaryButton(
                verbatim: L("nextstep.timer.label") + " " + L("nextstep.timer.minutes", proposal.timerMinutes),
                systemImage: "play.fill",
                accessibilityId: "nextstep.start"
            ) {
                onStart()
            }

            QuietButton("nextstep.makeSmaller", systemImage: "arrow.down.right", accessibilityId: "nextstep.makeSmaller") {
                onShrink()
            }
            .disabled(proposal.shrinkLevel == .three)

            moreActions
        }
        .startKindCard()
    }

    private var headerRow: some View {
        HStack(spacing: Theme.spacing8) {
            Label {
                Text(verbatim: proposal.category == .other
                    ? L("nextstep.genericLabel")
                    : L(proposal.category.localizationKey))
                    .font(.caption)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: proposal.category == .other
                    ? "arrow.forward.circle.fill"
                    : proposal.category.systemImage)
            }
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("nextstep.category")

            Spacer()

            if proposal.shrinkLevel != .zero {
                Text(verbatim: L("nextstep.shrink.level"))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, Theme.spacing8)
                    .padding(.vertical, Theme.spacing4)
                    .background(Theme.softAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var shareText: String {
        [
            "StartKind",
            proposal.title,
            proposal.step,
            L("timer.stopHint", proposal.stopCondition),
            L("nextstep.timer.minutes", proposal.timerMinutes),
            AppStoreLinks.shareURL("step").absoluteString
        ].joined(separator: "\n")
    }

    private var stopRow: some View {
        HStack(alignment: .top, spacing: Theme.spacing8) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(.secondary)
                .font(.caption)
                .frame(width: 18)
            Text(verbatim: proposal.stopCondition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warmWash.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .accessibilityIdentifier("nextstep.stop")
    }

    private var moreActions: some View {
        DisclosureGroup(isExpanded: $moreActionsExpanded) {
            VStack(alignment: .leading, spacing: Theme.spacing12) {
                Button {
                    withAnimation(reduceMotion ? nil : .default) { showPlan.toggle() }
                } label: {
                    Label(L(showPlan ? "nextstep.hidePlan" : "nextstep.showPlan"), systemImage: "list.bullet")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .pressableCard()
                .disabled(proposal.whyThisStep == nil)
                .accessibilityIdentifier("nextstep.showPlan")

                if showPlan, let why = proposal.whyThisStep {
                    Text(verbatim: why)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("nextstep.plan")
                }

                HStack(spacing: Theme.spacing8) {
                    ShareLink(item: shareText) {
                        Label(L("nextstep.share"), systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("nextstep.share")

                    Button {
                        onSaveToVault()
                    } label: {
                        Label(L("nextstep.saveVault"), systemImage: "tray.and.arrow.down.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("nextstep.saveVault")
                }

                actionPrepRow
                startLadderRow

                QuietButton("costart.cta", systemImage: "person.2.wave.2", accessibilityId: "nextstep.costart") {
                    onCoStart()
                }

                Button(role: .cancel) {
                    onSkip()
                } label: {
                    Label(L("timer.outcome.skipped"), systemImage: "arrow.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .pressableCard()
                .accessibilityIdentifier("nextstep.moveOn")
            }
            .padding(.top, Theme.spacing8)
        } label: {
            Label(L("nextstep.moreActions"), systemImage: moreActionsExpanded ? "ellipsis.circle.fill" : "ellipsis.circle")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .accessibilityIdentifier("nextstep.moreActions")
        }
        .accessibilityHint(Text(verbatim: L("nextstep.moreActions.hint")))
    }

    @ViewBuilder
    private var actionPrepRow: some View {
        if let actionPrep {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Text(verbatim: L("nextstep.actionPrep.title"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Label(actionPrep.label, systemImage: actionPrep.url == nil ? "rectangle.and.pencil.and.ellipsis" : "arrow.up.right.square")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                Text(verbatim: actionPrep.instruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if actionPrep.url != nil {
                    Button {
                        onPrepare(actionPrep)
                    } label: {
                        Text(verbatim: actionPrep.label)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .pressableCard()
                    .accessibilityIdentifier("nextstep.prepare")
                }
            }
            .padding(Theme.spacing12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.softAccent.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .accessibilityIdentifier("nextstep.actionPrep")
        }
    }

    private var startLadderRow: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: L("ladder.title"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("nextstep.ladder")
            HStack(spacing: Theme.spacing8) {
                ForEach(StartLadderPlanner.minutes, id: \.self) { minutes in
                    Button {
                        onUseStartLadder(minutes)
                    } label: {
                        Text(verbatim: L("ladder.minutes", minutes))
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                            .foregroundStyle(Theme.accent)
                            .background(Theme.softAccent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    }
                    .pressableCard()
                    .accessibilityIdentifier("nextstep.ladder.\(minutes)")
                }
            }
        }
    }
}
