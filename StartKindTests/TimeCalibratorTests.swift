import XCTest
@testable import StartKind

final class TimeCalibratorTests: XCTestCase {
    let calibrator = TimeCalibrator()

    private func sample(_ category: TaskCategory = .bills, estimate: Int = 10, actual: Int = 600, outcome: TimerOutcome = .completed, hour: Int = 9, coStart: Bool = false) -> CalibrationSample {
        CalibrationSample(category: category, estimatedMinutes: estimate, actualSeconds: actual, outcome: outcome, startHour: hour, coStartUsed: coStart)
    }

    func testMultiplierIsOneWithNoSamples() {
        XCTAssertEqual(calibrator.multiplier(for: .bills, in: []), 1.0)
    }

    func testMultiplierReflectsOverestimate() {
        let samples = [sample(estimate: 10, actual: 900)] // actual 15m
        let m = calibrator.multiplier(for: .bills, in: samples)
        XCTAssertEqual(m, 1.5, accuracy: 0.15)
    }

    func testMultiplierClampedToRange() {
        let samples = [sample(estimate: 5, actual: 3600)] // actual 60m, ratio 12 -> clamp 2.5
        let m = calibrator.multiplier(for: .bills, in: samples)
        XCTAssertLessThanOrEqual(m, 2.5)
    }

    func testCompletionRate() {
        let samples = [sample(outcome: .completed), sample(outcome: .partial), sample(outcome: .completed)]
        XCTAssertEqual(calibrator.completionRate(for: .bills, in: samples), 2.0 / 3.0, accuracy: 0.01)
    }

    func testBestStartWindow() {
        let samples = [
            sample(outcome: .completed, hour: 9),
            sample(outcome: .completed, hour: 10),
            sample(outcome: .abandoned, hour: 21)
        ]
        XCTAssertEqual(calibrator.bestStartWindow(for: .bills, in: samples), "morning")
    }

    func testCoStartImpactHelped() {
        let samples = [
            sample(outcome: .completed, coStart: true),
            sample(outcome: .completed, coStart: true),
            sample(outcome: .abandoned, coStart: false),
            sample(outcome: .abandoned, coStart: false)
        ]
        let impact = calibrator.coStartImpact(in: samples)
        XCTAssertTrue(impact.helped)
        XCTAssertEqual(impact.finished, 2)
        XCTAssertEqual(impact.total, 2)
    }

    func testInsightsAreNonShaming() {
        let samples = [sample(estimate: 10, actual: 900, outcome: .completed)]
        let insights = calibrator.insights(samples: samples, language: "en")
        XCTAssertFalse(insights.isEmpty)
        for insight in insights {
            let lower = insight.lowercased()
            XCTAssertFalse(lower.contains("fail"))
            XCTAssertFalse(lower.contains("behind"))
            XCTAssertFalse(lower.contains("missed"))
        }
    }

    func testSnapshotAggregates() {
        let samples = [sample(estimate: 10, actual: 900, outcome: .completed)]
        let snap = calibrator.snapshot(for: .bills, in: samples)
        XCTAssertEqual(snap.category, .bills)
        XCTAssertEqual(snap.sampleCount, 1)
        XCTAssertEqual(snap.estimateMultiplier, 1.5, accuracy: 0.15)
    }
}
