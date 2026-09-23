import Foundation

/// Timing control for App Store review requests.
///
/// The system shows the native prompt at most 3 times in any 365-day window,
/// and whether it actually appears at all is entirely up to iOS — the only
/// thing we control is when to ask. Rule: only ask right after the person has
/// just finished a next step, never on first launch or onboarding, at most
/// once per app version, and no more than once every few months even across
/// version bumps.
///
/// Usage: call `recordValueMoment()` right after a step completes. When it
/// returns true, trigger SwiftUI's `\.requestReview` environment action.
@MainActor
enum ReviewPrompter {
    /// How many completed steps before we ask for the first time.
    private static let momentsBeforeAsking = 5
    /// Floor between asks, even if the version changed in between.
    private static let minimumDaysBetweenPrompts = 90

    private static let momentCountKey = "review.valueMomentCount"
    private static let promptedVersionKey = "review.promptedVersion"
    private static let lastPromptDateKey = "review.lastPromptDate"

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Records one completed step. Returns true when this is an appropriate
    /// moment to ask: enough value moments have accumulated, this version
    /// hasn't been asked yet, and the minimum gap since the last ask has
    /// passed.
    @discardableResult
    static func recordValueMoment(defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        let count = defaults.integer(forKey: momentCountKey) + 1
        defaults.set(count, forKey: momentCountKey)

        guard count >= momentsBeforeAsking else { return false }
        guard defaults.string(forKey: promptedVersionKey) != currentVersion else { return false }
        if let lastPrompt = defaults.object(forKey: lastPromptDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            guard daysSince >= minimumDaysBetweenPrompts else { return false }
        }

        defaults.set(currentVersion, forKey: promptedVersionKey)
        defaults.set(now, forKey: lastPromptDateKey)
        return true
    }

    /// For tests and "reset all data".
    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: momentCountKey)
        defaults.removeObject(forKey: promptedVersionKey)
        defaults.removeObject(forKey: lastPromptDateKey)
    }
}
