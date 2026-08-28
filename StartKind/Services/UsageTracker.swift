import Foundation

/// Tracks daily Free-tier usage with automatic overnight reset.
/// Persisted in UserDefaults so it survives launches without an account.
@MainActor
final class UsageTracker: ObservableObject {
    @Published private(set) var usage: UsageState

    private let defaults: UserDefaults
    private let now: () -> Date
    private let keyDate = "sk.usage.date"
    private let keySteps = "sk.usage.steps"
    private let keyAdmin = "sk.usage.admin"
    static let keyFriendCoStartWindowStart = "sk.usage.friendCoStartWindowStart"
    static let keyFriendCoStartsUsed = "sk.usage.friendCoStartsUsed"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        self.usage = Self.load(defaults: defaults, now: now())
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

    func recordFriendCoStart(isPlus: Bool = false) {
        guard !isPlus else { return }
        resetIfNeeded()
        refreshFriendCoStartWindowIfNeeded()
        guard usage.friendCoStartsRemaining > 0 else { return }
        if usage.friendCoStartsUsedInWindow == 0 {
            usage.friendCoStartWindowStart = now()
        }
        usage.friendCoStartsUsedInWindow += 1
        save()
    }

    func canGenerateStep(isPlus: Bool) -> Bool {
        resetIfNeeded()
        return isPlus || usage.canGenerateStep
    }

    func canUseAdminQuickStart(isPlus: Bool) -> Bool {
        resetIfNeeded()
        return isPlus || usage.canUseAdminQuickStart
    }

    func canCreateFriendCoStart(isPlus: Bool) -> Bool {
        resetIfNeeded()
        if isPlus { return true }
        refreshFriendCoStartWindowIfNeeded()
        return usage.canCreateFriendCoStart
    }

    func currentUsage() -> UsageState {
        resetIfNeeded()
        refreshFriendCoStartWindowIfNeeded()
        return usage
    }

    private func resetIfNeeded() {
        let currentDate = now()
        guard Self.dateString(currentDate) != defaults.string(forKey: keyDate) else { return }

        // Daily counters reset independently. The friend allowance is a rolling
        // window and must remain intact across the overnight reset.
        usage = UsageState(
            stepsUsedToday: 0,
            stepsLimit: UsageLimits.freeStepsPerDay,
            adminQuickStartsUsedToday: 0,
            adminQuickStartLimit: UsageLimits.freeAdminQuickStartsPerDay,
            friendCoStartsUsedInWindow: usage.friendCoStartsUsedInWindow,
            friendCoStartLimit: UsageLimits.freeFriendCoStartPerWindow,
            friendCoStartWindowStart: usage.friendCoStartWindowStart,
            resetsAt: Self.nextReset(from: currentDate)
        )
        save(at: currentDate)
    }

    private func refreshFriendCoStartWindowIfNeeded() {
        guard usage.friendCoStartsUsedInWindow > 0 else { return }
        guard let windowStart = usage.friendCoStartWindowStart else {
            usage.friendCoStartsUsedInWindow = 0
            usage.friendCoStartWindowStart = nil
            save()
            return
        }
        let windowEndsAt = windowStart.addingTimeInterval(TimeInterval(UsageLimits.freeFriendCoStartWindowDays * 24 * 60 * 60))
        if now() >= windowEndsAt {
            usage.friendCoStartsUsedInWindow = 0
            usage.friendCoStartWindowStart = nil
            save()
        }
    }

    private func save(at date: Date? = nil) {
        let currentDate = date ?? now()
        defaults.set(Self.dateString(currentDate), forKey: keyDate)
        defaults.set(usage.stepsUsedToday, forKey: keySteps)
        defaults.set(usage.adminQuickStartsUsedToday, forKey: keyAdmin)
        if let windowStart = usage.friendCoStartWindowStart {
            defaults.set(windowStart, forKey: UsageTracker.keyFriendCoStartWindowStart)
        } else {
            defaults.removeObject(forKey: UsageTracker.keyFriendCoStartWindowStart)
        }
        defaults.set(usage.friendCoStartsUsedInWindow, forKey: UsageTracker.keyFriendCoStartsUsed)
    }

    private static func load(defaults: UserDefaults, now: Date) -> UsageState {
        let today = dateString(now)
        let stored = defaults.string(forKey: "sk.usage.date")
        let steps = defaults.integer(forKey: "sk.usage.steps")
        let admin = defaults.integer(forKey: "sk.usage.admin")
        let friendCoStartsUsed = defaults.integer(forKey: keyFriendCoStartsUsed)
        let friendCoStartWindowStart = defaults.object(forKey: keyFriendCoStartWindowStart) as? Date
        let usedToday = (stored == today) ? steps : 0
        let adminToday = (stored == today) ? admin : 0
        return UsageState(
            stepsUsedToday: usedToday,
            stepsLimit: UsageLimits.freeStepsPerDay,
            adminQuickStartsUsedToday: adminToday,
            adminQuickStartLimit: UsageLimits.freeAdminQuickStartsPerDay,
            friendCoStartsUsedInWindow: friendCoStartsUsed,
            friendCoStartLimit: UsageLimits.freeFriendCoStartPerWindow,
            friendCoStartWindowStart: friendCoStartWindowStart,
            resetsAt: nextReset(from: now)
        )
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dateString(_ date: Date) -> String { formatter.string(from: date) }

    private static func nextReset(from date: Date) -> Date {
        Calendar.current.startOfDay(for: date).addingTimeInterval(86_400)
    }
}
