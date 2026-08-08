import Foundation

/// Free-tier limits and Plus gates. Mirrors `docs/SUBSCRIPTION_STRATEGY.md`.
enum UsageLimits {
    static let freeStepsPerDay = 5
    static let freeAdminQuickStartsPerDay = 1
    static let freeHistoryDays = 14
    static let freeActiveRecoveryCapsules = 1
    static let trialDays = 7

    /// Timer presets available to everyone (Free + Plus).
    static let timerPresets: [Int] = [5, 10, 15, 25]

    /// Features gated behind Plus.
    enum PlusFeature {
        case unlimitedSteps
        case adminTaskReader
        case screenshotPhoto
        case calendarSync
        case emailParsing
        case unlimitedRecovery
        case aiCoStart
        case friendCoStart
        case crossDeviceSync
        case personalExecutionModel
    }

    static func isGated(_ feature: PlusFeature, entitlement: EntitlementState) -> Bool {
        switch feature {
        case .unlimitedSteps, .adminTaskReader, .screenshotPhoto, .calendarSync,
             .emailParsing, .unlimitedRecovery, .aiCoStart, .friendCoStart,
             .crossDeviceSync, .personalExecutionModel:
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
