import Foundation

/// Tracks daily Free-tier usage with automatic overnight reset.
/// Persisted in UserDefaults so it survives launches without an account.
@MainActor
final class UsageTracker: ObservableObject {
    @Published private(set) var usage: UsageState

    private let defaults: UserDefaults
    private let keyDate = "sk.usage.date"
    private let keySteps = "sk.usage.steps"
    private let keyAdmin = "sk.usage.admin"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.usage = Self.load(defaults: defaults)
    }

    func recordStepGeneration() {
        resetIfNeeded()
        usage.stepsUsedToday += 1
        save()
    }

    func recordAdminQuickStart() {
        resetIfNeeded()
        usage.adminQuickStartsUsedToday += 1
        save()
    }

    func canGenerateStep(isPlus: Bool) -> Bool { isPlus || usage.canGenerateStep }
    func canUseAdminQuickStart(isPlus: Bool) -> Bool { isPlus || usage.canUseAdminQuickStart }

    private func resetIfNeeded() {
        if Self.dateString(.now) != defaults.string(forKey: keyDate) {
            usage = UsageState(
                stepsUsedToday: 0,
                stepsLimit: UsageLimits.freeStepsPerDay,
                adminQuickStartsUsedToday: 0,
                adminQuickStartLimit: UsageLimits.freeAdminQuickStartsPerDay,
                resetsAt: Self.nextReset()
            )
        }
    }

    private func save() {
        defaults.set(Self.dateString(.now), forKey: keyDate)
        defaults.set(usage.stepsUsedToday, forKey: keySteps)
        defaults.set(usage.adminQuickStartsUsedToday, forKey: keyAdmin)
    }

    private static func load(defaults: UserDefaults) -> UsageState {
        let today = dateString(.now)
        let stored = defaults.string(forKey: "sk.usage.date")
        let steps = defaults.integer(forKey: "sk.usage.steps")
        let admin = defaults.integer(forKey: "sk.usage.admin")
        let usedToday = (stored == today) ? steps : 0
        let adminToday = (stored == today) ? admin : 0
        return UsageState(
            stepsUsedToday: usedToday,
            stepsLimit: UsageLimits.freeStepsPerDay,
            adminQuickStartsUsedToday: adminToday,
            adminQuickStartLimit: UsageLimits.freeAdminQuickStartsPerDay,
            resetsAt: nextReset()
        )
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dateString(_ date: Date) -> String { formatter.string(from: date) }

    private static func nextReset() -> Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
    }
}
