import Foundation

/// One observed timing sample, derived from a completed/paused TimerSession.
/// Pure value type so calibration logic is fully unit-testable without SwiftData.
struct CalibrationSample: Sendable, Equatable {
    let category: TaskCategory
    let estimatedMinutes: Int
    let actualSeconds: Int
    let outcome: TimerOutcome
    let startHour: Int // 0...23
    let coStartUsed: Bool

    var actualMinutes: Double { Double(actualSeconds) / 60.0 }
    var countedTowardTime: Bool { outcome == .completed || outcome == .partial }
}

/// Personal Time Calibration.
///
/// Learns per-category multipliers from actual elapsed time, plus best start
/// windows and co-start impact. Insights are strictly non-shaming.
/// See `docs/PRODUCT_REQUIREMENTS.md` §4.
struct TimeCalibrator: Sendable {
    init() {}

    // MARK: - Per-category stats

    func multiplier(for category: TaskCategory, in samples: [CalibrationSample]) -> Double {
        let cat = samples.filter { $0.category == category && $0.countedTowardTime }
        guard !cat.isEmpty else { return 1.0 }
        let estimates = cat.map(\.estimatedMinutes).compactMap { $0 > 0 ? $0 : nil }
        guard !estimates.isEmpty else { return 1.0 }
        let medEst = Self.median(estimates.map(Double.init))
        let medAct = Self.median(cat.map(\.actualMinutes))
        guard medEst > 0 else { return 1.0 }
        let m = medAct / medEst
        return min(2.5, max(0.5, (m * 10).rounded() / 10))
    }

    func medianActual(for category: TaskCategory, in samples: [CalibrationSample]) -> Double? {
        let act = samples.filter { $0.category == category && $0.countedTowardTime }.map(\.actualMinutes)
        return act.isEmpty ? nil : Self.median(act)
    }

    func completionRate(for category: TaskCategory, in samples: [CalibrationSample]) -> Double {
        let cat = samples.filter { $0.category == category }
        guard !cat.isEmpty else { return 0 }
        let done = cat.filter { $0.outcome == .completed }.count
        return Double(done) / Double(cat.count)
    }

    func bestStartWindow(for category: TaskCategory, in samples: [CalibrationSample]) -> String? {
        let cat = samples.filter { $0.category == category }
        guard cat.count >= 3 else { return nil }
        let buckets: [(String, [CalibrationSample])] = [
            ("morning", cat.filter { (5...12).contains($0.startHour) }),
            ("afternoon", cat.filter { (13...18).contains($0.startHour) }),
            ("evening", cat.filter { (19...23).contains($0.startHour) || (0...4).contains($0.startHour) })
        ]
        let ranked = buckets
            .filter { !$0.1.isEmpty }
            .map { (name: $0.0, rate: Double($0.1.filter { $0.outcome == .completed }.count) / Double($0.1.count), count: $0.1.count) }
            .filter { $0.count >= 2 }
        guard let best = ranked.max(by: { $0.rate < $1.rate }), best.rate > 0 else { return nil }
        return best.name
    }

    func snapshot(for category: TaskCategory, in samples: [CalibrationSample]) -> CalibrationSnapshot {
        CalibrationSnapshot(
            category: category,
            estimateMultiplier: multiplier(for: category, in: samples),
            medianActualMinutes: medianActual(for: category, in: samples),
            completionRate: completionRate(for: category, in: samples),
            bestStartWindow: bestStartWindow(for: category, in: samples),
            sampleCount: samples.filter { $0.category == category }.count
        )
    }

    // MARK: - Co-start impact

    struct CoStartImpact: Sendable {
        let helped: Bool
        let finished: Int
        let total: Int
    }

    func coStartImpact(in samples: [CalibrationSample]) -> CoStartImpact {
        let co = samples.filter { $0.coStartUsed }
        guard co.count >= 2 else { return CoStartImpact(helped: false, finished: 0, total: co.count) }
        let finished = co.filter { $0.outcome == .completed }.count
        let solo = samples.filter { !$0.coStartUsed }
        let soloRate = solo.isEmpty ? 0 : Double(solo.filter { $0.outcome == .completed }.count) / Double(solo.count)
        let coRate = Double(finished) / Double(co.count)
        return CoStartImpact(helped: coRate > soloRate, finished: finished, total: co.count)
    }

    // MARK: - Insights (non-shaming)

    /// Generate gentle, observation-style insights. Never uses failure language.
    func insights(samples: [CalibrationSample], language: String) -> [String] {
        var result: [String] = []
        let categories = Set(samples.map(\.category))
        for category in categories.sorted(by: { $0.localizationKey < $1.localizationKey }) {
            let snap = snapshot(for: category, in: samples)
            if snap.estimateMultiplier >= 1.2 {
                result.append(L("patterns.insight.longer", L(category.localizationKey)))
            }
            if let window = snap.bestStartWindow {
                result.append(L("patterns.insight.window", windowDisplayName(window)))
            }
        }
        let impact = coStartImpact(in: samples)
        if impact.helped, impact.total >= 2 {
            result.append(L("patterns.insight.costart", impact.finished))
        }
        return result
    }

    private func windowDisplayName(_ window: String) -> String {
        L("window.\(window)")
    }

    // MARK: - Helpers

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
