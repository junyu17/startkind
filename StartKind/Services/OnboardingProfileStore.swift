import Foundation
import Combine

/// The small set of common reasons a person may find starting difficult.
/// This is local setup context, not a permanent task mode or product fork.
enum StartDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case gettingStarted = "getting_started"
    case tasksTooBig = "tasks_too_big"
    case interruptions
    case adminPileUp = "admin_pile_up"

    var id: String { rawValue }

    var titleKey: String { "onboarding.difficulty.\(rawValue).title" }
    var detailKey: String { "onboarding.difficulty.\(rawValue).detail" }
    var hintKey: String { "start.difficultyHint.\(rawValue)" }
    var systemImage: String {
        switch self {
        case .gettingStarted: return "play.circle"
        case .tasksTooBig: return "arrow.down.right.circle"
        case .interruptions: return "bell.slash"
        case .adminPileUp: return "tray.full"
        }
    }
}

/// Stores first-run setup separately from the SwiftData/CloudKit profile.
/// The answers are lightweight local preferences used only to personalize the
/// first screen and the default co-start guest name.
@MainActor
final class OnboardingProfileStore: ObservableObject {
    @Published private(set) var firstName: String
    @Published private(set) var difficulty: StartDifficulty?
    @Published private(set) var isComplete: Bool

    private let defaults: UserDefaults

    private enum Key {
        static let firstName = "startkind.onboarding.firstName"
        static let difficulty = "startkind.onboarding.difficulty"
        static let completed = "startkind.onboarding.completed"
    }

    init(
        defaults: UserDefaults = .standard,
        skipOnboarding: Bool = false,
        forceOnboarding: Bool = false
    ) {
        self.defaults = defaults

        if forceOnboarding {
            defaults.removeObject(forKey: Key.firstName)
            defaults.removeObject(forKey: Key.difficulty)
            defaults.removeObject(forKey: Key.completed)
        }

        let storedName = Self.normalizedFirstName(defaults.string(forKey: Key.firstName) ?? "")
        let storedDifficulty = defaults.string(forKey: Key.difficulty)
            .flatMap(StartDifficulty.init(rawValue:))
        self.firstName = storedName
        self.difficulty = storedDifficulty
        self.isComplete = !forceOnboarding && (
            skipOnboarding || (
                defaults.bool(forKey: Key.completed) &&
                Self.isValidFirstName(storedName) &&
                storedDifficulty != nil
            )
        )
    }

    static func normalizedFirstName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidFirstName(_ value: String) -> Bool {
        let normalized = normalizedFirstName(value)
        return !normalized.isEmpty && normalized.count <= 40
    }

    @discardableResult
    func save(firstName: String, difficulty: StartDifficulty) -> Bool {
        guard Self.isValidFirstName(firstName) else { return false }

        let normalizedName = Self.normalizedFirstName(firstName)
        defaults.set(normalizedName, forKey: Key.firstName)
        defaults.set(difficulty.rawValue, forKey: Key.difficulty)
        defaults.set(true, forKey: Key.completed)
        self.firstName = normalizedName
        self.difficulty = difficulty
        self.isComplete = true
        return true
    }

    func reset() {
        defaults.removeObject(forKey: Key.firstName)
        defaults.removeObject(forKey: Key.difficulty)
        defaults.removeObject(forKey: Key.completed)
        firstName = ""
        difficulty = nil
        isComplete = false
    }
}
