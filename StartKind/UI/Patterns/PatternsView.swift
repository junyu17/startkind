import SwiftUI

struct PatternsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager

    private var insights: [String] { env.insights() }
    private var snapshots: [CalibrationSnapshot] { env.snapshots() }
    private var frictionInsights: [FrictionInsight] { env.frictionInsights() }
    private var gentleReview: GentleReviewSummary { env.gentleReviewSummary() }
    private var startProfile: StartProfile { env.startProfile() }
    @State private var advancedDetailsExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    recommendationCard
                    startProfileCard
                    gentleReviewCard
                    Text(verbatim: L("patterns.noShame"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if env.isPlus {
                        advancedDetails
                    } else {
                        plusPromo
                    }
                }
                .padding()
            }
            .navigationTitle(L("patterns.title"))
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Label(L("patterns.recommendation.title"), systemImage: "arrow.down.right.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text(verbatim: gentleReview.message)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .startKindCard()
        .accessibilityIdentifier("patterns.recommendation")
    }

    private var emptyState: some View {
        Text(verbatim: L("patterns.empty"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.spacing32)
    }

    private var gentleReviewCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Theme.accent)
                Text(verbatim: L("gentleReview.title"))
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: Theme.spacing8) {
                modelMetric(title: L("gentleReview.starts"), value: "\(gentleReview.startsThisWeek)", icon: "play.circle.fill")
                modelMetric(title: L("gentleReview.friction"), value: gentleReviewFrictionText, icon: "exclamationmark.circle")
            }
        }
        .startKindCard()
        .accessibilityIdentifier("gentleReview.card")
    }

    private var gentleReviewFrictionText: String {
        guard let preset = gentleReview.mostCommonFriction else { return L("gentleReview.none") }
        return L("frictionPreset.\(preset.rawValue)")
    }

    private var frictionMapSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "map")
                    .foregroundStyle(Theme.accent)
                Text(verbatim: L("friction.title"))
                    .font(.headline)
                Spacer()
            }

            if frictionInsights.isEmpty {
                Text(verbatim: L("friction.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(frictionInsights) { insight in
                    VStack(alignment: .leading, spacing: Theme.spacing8) {
                        Label {
                            Text(verbatim: insight.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } icon: {
                            Image(systemName: insight.blocker?.systemImage ?? insight.category.systemImage)
                        }
                        .foregroundStyle(Theme.accent)

                        Text(verbatim: insight.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(verbatim: insight.suggestedStep)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.ink)
                            .padding(Theme.spacing8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.warmWash.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                    }
                    .accessibilityIdentifier("friction.insight")
                }
            }
        }
        .startKindCard()
    }

    private var startProfileCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(Theme.accent)
                Text(verbatim: L("startProfile.title"))
                    .font(.headline)
                Spacer()
            }

            Text(verbatim: startProfileSummary)
                .font(.subheadline)
                .foregroundStyle(startProfile.sampleCount == 0 ? .secondary : Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if startProfile.sampleCount > 0 {
                HStack(spacing: Theme.spacing8) {
                    modelMetric(title: L("startProfile.window"), value: startProfileWindow, icon: "clock")
                    modelMetric(title: L("startProfile.duration"), value: startProfileDuration, icon: "timer")
                    modelMetric(title: L("startProfile.category"), value: startProfileCategory, icon: "checkmark.circle")
                }
            }
        }
        .startKindCard()
        .accessibilityIdentifier("startProfile.card")
    }

    private var advancedDetails: some View {
        DisclosureGroup(isExpanded: $advancedDetailsExpanded) {
            if advancedDetailsExpanded {
                VStack(alignment: .leading, spacing: Theme.spacing16) {
                    executionModelCard
                    frictionMapSection

                    if insights.isEmpty && snapshots.isEmpty && frictionInsights.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                            KindBanner(text: insight)
                        }
                        ForEach(snapshots) { snapshot in
                            snapshotCard(snapshot)
                        }
                    }
                }
                .padding(.top, Theme.spacing8)
            }
        } label: {
            Label(
                L("patterns.advanced.title"),
                systemImage: advancedDetailsExpanded ? "chevron.down.circle" : "chevron.right.circle"
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
            .accessibilityIdentifier("patterns.advanced")
        }
        .accessibilityHint(Text(verbatim: L("patterns.advanced.hint")))
    }

    private var startProfileSummary: String {
        guard startProfile.sampleCount > 0 else { return L("startProfile.empty") }
        return L("startProfile.summary")
    }

    private var startProfileWindow: String {
        startProfile.preferredWindow.map { L("window.\($0.rawValue)") } ?? L("startProfile.learning")
    }

    private var startProfileDuration: String {
        startProfile.helpfulMinutes.map { L("startProfile.minutes", $0) } ?? L("startProfile.learning")
    }

    private var startProfileCategory: String {
        startProfile.productiveCategory.map { L($0.localizationKey) } ?? L("startProfile.learning")
    }

    private var executionModelCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(Theme.accent)
                Text(verbatim: L("patterns.model.title"))
                    .font(.headline)
                Spacer()
                Text(verbatim: L("patterns.model.samples", totalSampleCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("patterns.model.summary")

            if let strongest = strongestSnapshot {
                Text(verbatim: modelSummary(for: strongest))
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(verbatim: L("patterns.model.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let blocker = env.activeCapsule()?.blockerReason {
                Label(L("patterns.model.blocker", L(blocker.localizationKey)), systemImage: blocker.systemImage)
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("patterns.model.blocker")
            }

            HStack(spacing: Theme.spacing8) {
                modelMetric(
                    title: L("patterns.model.stepSize"),
                    value: suggestedStepSize,
                    icon: "arrow.down.right"
                )
                modelMetric(
                    title: L("patterns.model.bestWindow"),
                    value: bestWindowText,
                    icon: "clock"
                )
            }
        }
        .startKindCard()
    }

    private func modelMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        .padding(Theme.spacing12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private func snapshotCard(_ snap: CalibrationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing10) {
            Label {
                Text(verbatim: L(snap.category.localizationKey))
            } icon: {
                Image(systemName: snap.category.systemImage)
            }
            .foregroundStyle(Theme.accent)

            if let median = snap.medianActualMinutes {
                Text(verbatim: L("patterns.medianActual", "\(Int(median)) min"))
                    .font(.subheadline)
            }
            Text(verbatim: L("patterns.estimateMultiplier", String(format: "%.1fx", snap.estimateMultiplier)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let window = snap.bestStartWindow {
                Text(verbatim: L("patterns.bestWindow", L("window.\(window)")))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            let completed = Int((snap.completionRate * Double(snap.sampleCount)).rounded())
            Text(verbatim: L("patterns.completion", completed, snap.sampleCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(verbatim: L("patterns.sample.count", snap.sampleCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: recommendation(for: snap))
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .padding(.top, Theme.spacing4)
        }
        .startKindCard()
    }

    private var plusPromo: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: L("patterns.unlock.title")).font(.headline)
            Text(verbatim: L("patterns.unlock.body")).font(.subheadline).foregroundStyle(.secondary)
        }
        .startKindCard()
    }

    private var totalSampleCount: Int {
        snapshots.reduce(0) { $0 + $1.sampleCount }
    }

    private var strongestSnapshot: CalibrationSnapshot? {
        snapshots.max {
            abs($0.estimateMultiplier - 1.0) < abs($1.estimateMultiplier - 1.0)
        }
    }

    private var suggestedStepSize: String {
        guard let strongest = strongestSnapshot else { return L("patterns.model.stepSize.default") }
        if strongest.estimateMultiplier >= 1.25 || strongest.completionRate < 0.45 {
            return L("patterns.model.stepSize.tiny")
        }
        if strongest.estimateMultiplier >= 1.1 {
            return L("patterns.model.stepSize.small")
        }
        return L("patterns.model.stepSize.steady")
    }

    private var bestWindowText: String {
        let windows = snapshots.compactMap(\.bestStartWindow)
        guard !windows.isEmpty else { return L("patterns.model.bestWindow.pending") }
        let counts = Dictionary(grouping: windows, by: { $0 }).mapValues(\.count)
        guard let best = counts.max(by: { $0.value < $1.value })?.key else {
            return L("patterns.model.bestWindow.pending")
        }
        return L("window.\(best)")
    }

    private func modelSummary(for snap: CalibrationSnapshot) -> String {
        let category = L(snap.category.localizationKey)
        if snap.estimateMultiplier >= 1.25 {
            return L("patterns.model.summary.longer", category, String(format: "%.1fx", snap.estimateMultiplier))
        }
        if snap.completionRate < 0.45, snap.sampleCount >= 2 {
            return L("patterns.model.summary.tiny", category)
        }
        if let window = snap.bestStartWindow {
            return L("patterns.model.summary.window", category, L("window.\(window)"))
        }
        return L("patterns.model.summary.steady", category)
    }

    private func recommendation(for snap: CalibrationSnapshot) -> String {
        if snap.estimateMultiplier >= 1.25 {
            return L("patterns.recommendation.buffer", String(format: "%.1fx", snap.estimateMultiplier))
        }
        if snap.completionRate < 0.45, snap.sampleCount >= 2 {
            return L("patterns.recommendation.tiny")
        }
        if let window = snap.bestStartWindow {
            return L("patterns.recommendation.window", L("window.\(window)"))
        }
        return L("patterns.recommendation.keep")
    }
}
