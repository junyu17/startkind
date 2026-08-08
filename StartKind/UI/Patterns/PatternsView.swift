import SwiftUI

struct PatternsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager

    private var insights: [String] { env.insights() }
    private var snapshots: [CalibrationSnapshot] { env.snapshots() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    Text(verbatim: L("patterns.noShame"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if insights.isEmpty && snapshots.isEmpty {
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

    private func snapshotCard(_ snap: CalibrationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
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
            let completed = Int((snap.completionRate * Double(snap.sampleCount)).rounded())
            Text(verbatim: L("patterns.completion", completed, snap.sampleCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(verbatim: L("patterns.sample.count", snap.sampleCount))
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
