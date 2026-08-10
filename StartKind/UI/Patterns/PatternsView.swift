import SwiftUI

struct PatternsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager

    private var insights: [String] { env.insights() }
    private var snapshots: [CalibrationSnapshot] { env.snapshots() }
    private var frictionInsights: [FrictionInsight] { env.frictionInsights() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    executionModelCard
                    frictionMapSection

                    Text(verbatim: L("patterns.noShame"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

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

                    if !env.isPlus { plusPromo }
                }
                .padding()
            }
            .navigationTitle(L("patterns.title"))
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var emptyState: some View {
        Text(verbatim: L("patterns.empty"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.spacing32)
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
