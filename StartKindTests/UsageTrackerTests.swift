import XCTest
@testable import StartKind

@MainActor
final class UsageTrackerTests: XCTestCase {
    private func freshTracker() -> UsageTracker {
        UsageTracker(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testInitialUsageIsFull() {
        let tracker = freshTracker()
        XCTAssertEqual(tracker.usage.stepsRemaining, UsageLimits.freeStepsPerDay)
        XCTAssertTrue(tracker.canGenerateStep(isPlus: false))
    }

    func testIncrementConsumesStep() {
        let tracker = freshTracker()
        tracker.recordStepGeneration()
        XCTAssertEqual(tracker.usage.stepsRemaining, UsageLimits.freeStepsPerDay - 1)
    }

    func testExhaustingStepsBlocksFree() {
        let tracker = freshTracker()
        for _ in 0..<UsageLimits.freeStepsPerDay { tracker.recordStepGeneration() }
        XCTAssertFalse(tracker.canGenerateStep(isPlus: false))
        XCTAssertTrue(tracker.canGenerateStep(isPlus: true))
    }

    func testAdminQuickStartLimit() {
        let tracker = freshTracker()
        XCTAssertTrue(tracker.canUseAdminQuickStart(isPlus: false))
        tracker.recordAdminQuickStart()
        XCTAssertFalse(tracker.canUseAdminQuickStart(isPlus: false))
        XCTAssertTrue(tracker.canUseAdminQuickStart(isPlus: true))
    }

    func testPersistsAcrossInstances() {
        let suite = "test-suite-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let tracker1 = UsageTracker(defaults: defaults)
        tracker1.recordStepGeneration()
        tracker1.recordStepGeneration()
        let tracker2 = UsageTracker(defaults: defaults)
        XCTAssertEqual(tracker2.usage.stepsUsedToday, 2)
    }
}

final class UsageLimitsTests: XCTestCase {
    func testFreeGatesAllPlusFeatures() {
        for feature in [
            UsageLimits.PlusFeature.unlimitedSteps,
            .adminTaskReader,
            .screenshotPhoto,
            .calendarSync,
            .emailParsing,
            .unlimitedRecovery,
            .aiCoStart,
            .friendCoStart,
            .crossDeviceSync,
            .personalExecutionModel
        ] {
            XCTAssertTrue(UsageLimits.isGated(feature, entitlement: .free), "free should gate \(feature)")
        }
    }

    func testPlusActiveUnlocksAll() {
        for feature in [
            UsageLimits.PlusFeature.unlimitedSteps,
            .adminTaskReader,
            .crossDeviceSync,
            .personalExecutionModel
        ] {
            XCTAssertFalse(UsageLimits.isGated(feature, entitlement: .plusActive))
        }
    }

    func testTrialCountsAsPlus() {
        XCTAssertFalse(UsageLimits.isGated(.unlimitedSteps, entitlement: .plusTrial))
    }

    func testTimerPresetsAvailableToAll() {
        XCTAssertEqual(UsageLimits.timerPresets, [5, 10, 15, 25])
    }
}
