import Foundation

/// Free-tier limits and Plus gates. Mirrors `docs/SUBSCRIPTION_STRATEGY.md`.
enum UsageLimits {
    static let freeStepsPerDay = 5
    static let freeAdminQuickStartsPerDay = 1
    static let freeFriendCoStartPerWindow = 1
    static let freeFriendCoStartWindowDays = 7
    static let freeHistoryDays = 14
    static let freeActiveRecoveryCapsules = 1
    static let trialDays = 7

    /// Timer presets available to everyone (Free + Plus).
    static let timerPresets: [Int] = [5, 10, 15, 25]

    /// Features gated behind Plus.
    ///
    /// Private iCloud sync, local quiet co-start, the basic Start Profile,
    /// timers, templates, and the Personal Vault are intentionally absent:
    /// they are Free features. Photo OCR is part of Admin Quick Start rather
    /// than a separate entitlement.
    enum PlusFeature {
        case unlimitedDailyStarts
        case unlimitedAdminQuickStarts
        case unlimitedActiveRecoveryCapsules
        case unlimitedFriendRooms
        case advancedExecutionInsights
    }

    static func isGated(_ feature: PlusFeature, entitlement: EntitlementState) -> Bool {
        switch feature {
        case .unlimitedDailyStarts, .unlimitedAdminQuickStarts,
             .unlimitedActiveRecoveryCapsules, .unlimitedFriendRooms,
             .advancedExecutionInsights:
            return !entitlement.isPlus
        }
    }
}

/// Product IDs for StoreKit / Play Billing.
enum SubscriptionProductID {
    // Match the App Store Connect product IDs exactly (case-sensitive).
    static let monthly = "StartKind_plus_monthly"
    // Internal name `annual` maps to the yearly product.
    static let annual = "StartKind_plus_yearly"
    static let all = [monthly, annual]
}
