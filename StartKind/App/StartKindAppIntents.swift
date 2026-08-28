import AppIntents
import Foundation

enum StartKindIntentActionStore {
    static let suiteName = "group.ren.startkind"
    private static let key = "sk_pending_app_intent_action"

    static func save(_ kind: QuickActionKind) {
        defaults.set(kind.rawValue, forKey: key)
    }

    static func consume() -> QuickActionKind? {
        guard let rawValue = defaults.string(forKey: key),
              let kind = QuickActionKind(rawValue: rawValue) else { return nil }
        defaults.removeObject(forKey: key)
        return kind
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

struct StartKindEmergencyTinyIntent: AppIntent {
    static let title: LocalizedStringResource = "Start emergency tiny mode"
    static let description = IntentDescription("Open StartKind with a 3-minute emergency start.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        StartKindIntentActionStore.save(.emergencyTiny)
        return .result()
    }
}

struct StartKindStartFiveIntent: AppIntent {
    static let title: LocalizedStringResource = "Start 5 minutes"
    static let description = IntentDescription("Open StartKind with one 5-minute start.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        StartKindIntentActionStore.save(.startFive)
        return .result()
    }
}

struct StartKindStuckIntent: AppIntent {
    static let title: LocalizedStringResource = "I'm stuck"
    static let description = IntentDescription("Open StartKind with a smaller stuck step.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        StartKindIntentActionStore.save(.stuck)
        return .result()
    }
}

struct StartKindRescueYesterdayIntent: AppIntent {
    static let title: LocalizedStringResource = "Rescue yesterday"
    static let description = IntentDescription("Open StartKind with a gentle restart.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        StartKindIntentActionStore.save(.rescueYesterday)
        return .result()
    }
}

struct StartKindPasteAdminIntent: AppIntent {
    static let title: LocalizedStringResource = "Paste admin text"
    static let description = IntentDescription("Open StartKind ready to paste a bill, email, or appointment.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        StartKindIntentActionStore.save(.pasteAdmin)
        return .result()
    }
}

struct StartKindShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartKindEmergencyTinyIntent(),
            phrases: [
                "\(.applicationName) emergency start",
                "I'm a mess in \(.applicationName)"
            ],
            shortTitle: "Emergency",
            systemImageName: "bolt.heart"
        )
        AppShortcut(
            intent: StartKindStartFiveIntent(),
            phrases: [
                "\(.applicationName) start five minutes",
                "Start five minutes in \(.applicationName)"
            ],
            shortTitle: "Start 5",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StartKindStuckIntent(),
            phrases: [
                "\(.applicationName) I'm stuck",
                "I'm stuck in \(.applicationName)"
            ],
            shortTitle: "Stuck",
            systemImageName: "lifepreserver"
        )
        AppShortcut(
            intent: StartKindRescueYesterdayIntent(),
            phrases: [
                "\(.applicationName) rescue yesterday",
                "Rescue yesterday in \(.applicationName)"
            ],
            shortTitle: "Rescue",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: StartKindPasteAdminIntent(),
            phrases: [
                "\(.applicationName) paste admin text",
                "Paste admin text in \(.applicationName)"
            ],
            shortTitle: "Paste Admin",
            systemImageName: "doc.text"
        )
    }
}
