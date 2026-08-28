import XCTest
@testable import StartKind

/// What actually changes once someone subscribes. These gates decide whether a
/// paying user gets what they paid for, so each is asserted on both sides of
/// the boundary rather than only the free side.
@MainActor
final class PlusEntitlementTests: XCTestCase {

    private func tracker() -> UsageTracker {
        UsageTracker(defaults: UserDefaults(suiteName: "plus-\(UUID().uuidString)")!)
    }

    // MARK: - Daily step allowance

    func testFreeRunsOutOfStepsButPlusDoesNot() {
        let usage = tracker()
        for _ in 0..<UsageLimits.freeStepsPerDay { usage.recordStepGeneration() }

        XCTAssertFalse(usage.canGenerateStep(isPlus: false), "Free should be capped at the daily allowance")
        XCTAssertTrue(usage.canGenerateStep(isPlus: true), "Plus must not be capped")
    }

    func testPlusIsNotChargedAgainstTheDailyAllowance() {
        let usage = tracker()
        for _ in 0..<20 { _ = usage.canGenerateStep(isPlus: true) }
        XCTAssertEqual(usage.usage.stepsUsedToday, 0, "Checking the gate must not consume the allowance")
    }

    // MARK: - Admin Quick Start

    func testAdminQuickStartIsDailyForFreeAndUnlimitedForPlus() {
        let usage = tracker()
        for _ in 0..<UsageLimits.freeAdminQuickStartsPerDay { usage.recordAdminQuickStart() }

        XCTAssertFalse(usage.canUseAdminQuickStart(isPlus: false))
        XCTAssertTrue(usage.canUseAdminQuickStart(isPlus: true))
    }

    // MARK: - Friend co-start

    func testFriendCoStartIsWindowedForFreeAndUnlimitedForPlus() {
        let usage = tracker()
        usage.recordFriendCoStart(isPlus: false)

        XCTAssertFalse(usage.canCreateFriendCoStart(isPlus: false), "Free gets one per rolling window")
        XCTAssertTrue(usage.canCreateFriendCoStart(isPlus: true), "Plus must be unlimited")
    }

    func testPlusUsageIsNeverRecordedAgainstTheFriendWindow() {
        let usage = tracker()
        for _ in 0..<5 { usage.recordFriendCoStart(isPlus: true) }
        XCTAssertEqual(usage.usage.friendCoStartsUsedInWindow, 0, "A Plus room must not spend the free allowance")
        XCTAssertTrue(usage.canCreateFriendCoStart(isPlus: false), "…and must leave the free allowance intact")
    }

    // MARK: - Entitlement states

    func testEveryPaidStateGrantsPlusAndOthersDoNot() {
        for state in [EntitlementState.plusActive, .plusTrial, .plusGracePeriod] {
            XCTAssertTrue(state.isPlus, "\(state) should grant Plus")
        }
        for state in [EntitlementState.free, .plusExpired] {
            XCTAssertFalse(state.isPlus, "\(state) must not grant Plus")
        }
    }

    func testExpiredSubscriptionFallsBackToFreeLimits() {
        let usage = tracker()
        let expired = EntitlementState.plusExpired
        for _ in 0..<UsageLimits.freeStepsPerDay { usage.recordStepGeneration() }

        XCTAssertFalse(
            usage.canGenerateStep(isPlus: expired.isPlus),
            "An expired subscription must return to the free allowance, not stay unlimited"
        )
    }

    // MARK: - Gated feature list

    func testPlusFeaturesAreGatedForFreeAndOpenForPlus() {
        let gated: [UsageLimits.PlusFeature] = [
            .unlimitedSteps, .adminTaskReader, .screenshotPhoto, .calendarSync,
            .emailParsing, .unlimitedRecovery, .aiCoStart, .friendCoStart,
            .crossDeviceSync, .personalExecutionModel
        ]
        for feature in gated {
            XCTAssertTrue(UsageLimits.isGated(feature, entitlement: .free), "\(feature) should be gated on Free")
            XCTAssertFalse(UsageLimits.isGated(feature, entitlement: .plusActive), "\(feature) should open on Plus")
            XCTAssertFalse(UsageLimits.isGated(feature, entitlement: .plusTrial), "\(feature) should open during the trial")
        }
    }
}
