import XCTest
@testable import StartKind

@MainActor
final class UsageTrackerTests: XCTestCase {
    private func freshTracker() -> UsageTracker {
        UsageTracker(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    private func usageDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func fixedNow() -> Date {
        Calendar.current.date(from: DateComponents(year: 2040, month: 8, day: 26, hour: 12))!
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

    func testFriendCoStartAllowsOnePerSevenDayWindowForFreeUsers() {
        let tracker = freshTracker()
        XCTAssertTrue(tracker.canCreateFriendCoStart(isPlus: false))
        XCTAssertEqual(tracker.usage.friendCoStartsRemaining, UsageLimits.freeFriendCoStartPerWindow)
        tracker.recordFriendCoStart()
        XCTAssertFalse(tracker.canCreateFriendCoStart(isPlus: false))
        XCTAssertEqual(tracker.usage.friendCoStartsRemaining, 0)
    }

    func testFriendCoStartRecordStopsAtWindowLimit() {
        let tracker = freshTracker()
        tracker.recordFriendCoStart()
        tracker.recordFriendCoStart()
        XCTAssertEqual(tracker.usage.friendCoStartsUsedInWindow, 1)
        XCTAssertEqual(tracker.usage.friendCoStartsRemaining, 0)
    }

    func testFriendCoStartAllowanceResetsAfterSevenDays() {
        let suite = "friend-reset-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let now = fixedNow()
        let oldWindowStart = Calendar.current.date(byAdding: .day, value: -8, to: now)!
        defaults.set(1, forKey: UsageTracker.keyFriendCoStartsUsed)
        defaults.set(oldWindowStart, forKey: UsageTracker.keyFriendCoStartWindowStart)
        defaults.set(usageDateString(now), forKey: "sk.usage.date")

        let tracker = UsageTracker(defaults: defaults, now: { now })
        XCTAssertTrue(tracker.canCreateFriendCoStart(isPlus: false))
        XCTAssertEqual(tracker.usage.friendCoStartsUsedInWindow, 0)
        XCTAssertEqual(tracker.usage.friendCoStartsRemaining, UsageLimits.freeFriendCoStartPerWindow)
    }

    func testDailyResetPreservesFriendCoStartWindow() {
        let suite = "daily-reset-preserves-friend-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let now = fixedNow()
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let windowStart = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        defaults.set(usageDateString(previousDay), forKey: "sk.usage.date")
        defaults.set(UsageLimits.freeStepsPerDay, forKey: "sk.usage.steps")
        defaults.set(UsageLimits.freeAdminQuickStartsPerDay, forKey: "sk.usage.admin")
        defaults.set(1, forKey: UsageTracker.keyFriendCoStartsUsed)
        defaults.set(windowStart, forKey: UsageTracker.keyFriendCoStartWindowStart)

        let tracker = UsageTracker(defaults: defaults, now: { now })
        tracker.recordStepGeneration()

        XCTAssertEqual(tracker.usage.stepsUsedToday, 1)
        XCTAssertEqual(tracker.usage.adminQuickStartsUsedToday, 0)
        XCTAssertEqual(tracker.usage.friendCoStartsUsedInWindow, 1)
        XCTAssertEqual(tracker.usage.friendCoStartWindowStart, windowStart)

        let restored = UsageTracker(defaults: defaults, now: { now })
        XCTAssertEqual(restored.usage.friendCoStartsUsedInWindow, 1)
        XCTAssertEqual(restored.usage.friendCoStartWindowStart, windowStart)
        XCTAssertFalse(restored.canCreateFriendCoStart(isPlus: false))
    }

    func testPlusUsersCanAlwaysCreateFriendCoStart() {
        let tracker = freshTracker()
        tracker.recordFriendCoStart(isPlus: true)
        XCTAssertTrue(tracker.canCreateFriendCoStart(isPlus: true))
        XCTAssertTrue(tracker.canCreateFriendCoStart(isPlus: false))
        XCTAssertEqual(tracker.usage.friendCoStartsUsedInWindow, 0)
    }

    func testCurrentUsageRefreshesDailyCountersAfterMidnight() {
        let suite = "current-usage-midnight-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        var now = fixedNow()
        let tracker = UsageTracker(defaults: defaults, now: { now })
        tracker.recordStepGeneration()
        tracker.recordAdminQuickStart()

        now = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let refreshed = tracker.currentUsage()

        XCTAssertEqual(refreshed.stepsUsedToday, 0)
        XCTAssertEqual(refreshed.adminQuickStartsUsedToday, 0)
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
            UsageLimits.PlusFeature.unlimitedDailyStarts,
            .unlimitedAdminQuickStarts,
            .unlimitedActiveRecoveryCapsules,
            .unlimitedFriendRooms,
            .advancedExecutionInsights
        ] {
            XCTAssertTrue(UsageLimits.isGated(feature, entitlement: .free), "free should gate \(feature)")
        }
    }

    func testPlusActiveUnlocksAll() {
        for feature in [
            UsageLimits.PlusFeature.unlimitedDailyStarts,
            .unlimitedAdminQuickStarts,
            .unlimitedActiveRecoveryCapsules,
            .unlimitedFriendRooms,
            .advancedExecutionInsights
        ] {
            XCTAssertFalse(UsageLimits.isGated(feature, entitlement: .plusActive))
        }
    }

    func testTrialCountsAsPlus() {
        XCTAssertFalse(UsageLimits.isGated(.unlimitedDailyStarts, entitlement: .plusTrial))
    }

    func testTimerPresetsAvailableToAll() {
        XCTAssertEqual(UsageLimits.timerPresets, [5, 10, 15, 25])
    }
}
