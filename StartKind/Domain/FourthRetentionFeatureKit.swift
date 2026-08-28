import Foundation
import Combine

struct EmergencyTinyModePlanner: Sendable {
    func detectsTrigger(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["too much", "overwhelmed", "cannot start", "can't start", "i am a mess", "i'm a mess", "一团乱", "太乱", "崩溃"].contains { lower.contains($0) }
    }

    func proposal(language: String) -> NextStepProposal {
        let zh = language.lowercased().hasPrefix("zh")
        return NextStepProposal(title: zh ? "紧急 3 分钟模式" : "Emergency 3-minute mode", step: zh ? "呼气一次。只把一个需要的东西放到手边，然后停。" : "Take one exhale. Put one needed thing within reach, then stop.", timerMinutes: 3, stopCondition: zh ? "东西到手边就停。" : "Stop when one thing is within reach.", category: .other, shrinkLevel: .three, generatedBy: .localTemplate, whyThisStep: zh ? "过载时先降低阻力。" : "When overloaded, lower friction first.")
    }
}

enum QuickActionKind: String, CaseIterable, Sendable {
    case emergencyTiny
    case stuck
    case startFive
    case rescueYesterday
    case pasteAdmin

    var shortcutType: String { "ren.startkind.shortcut.\(rawValue)" }

    init?(shortcutType: String) {
        guard let raw = shortcutType.split(separator: ".").last.map(String.init) else { return nil }
        self.init(rawValue: raw)
    }

    func proposal(language: String) -> NextStepProposal? {
        let zh = language.lowercased().hasPrefix("zh")
        switch self {
        case .emergencyTiny:
            return EmergencyTinyModePlanner().proposal(language: language)
        case .stuck:
            return FrictionPresetPlanner().proposal(for: .tooVague, category: .other, language: language)
        case .startFive:
            return NextStepProposal(title: zh ? "开始 5 分钟" : "Start for 5 minutes", step: zh ? "打开最容易开始的地方，做 5 分钟。" : "Open the easiest doorway and work for 5 minutes.", timerMinutes: 5, stopCondition: zh ? "5 分钟到就停。" : "Stop at 5 minutes.", category: .other, shrinkLevel: .two, generatedBy: .localTemplate, whyThisStep: zh ? "主屏幕快捷启动。" : "Home screen quick start.")
        case .rescueYesterday:
            return NextStepProposal(title: zh ? "救回昨天 3 分钟" : "Rescue yesterday for 3 minutes", step: zh ? "只做昨天那件事的最小开头。" : "Do only the smallest start of yesterday's thing.", timerMinutes: 3, stopCondition: zh ? "开始过就算。" : "Starting counts.", category: .other, shrinkLevel: .three, generatedBy: .localTemplate, whyThisStep: zh ? "这是温和恢复。" : "This is a gentle restart.")
        case .pasteAdmin:
            return nil
        }
    }
}


enum DayPart: String, Codable, CaseIterable, Sendable {
    case morning, afternoon, evening
}

struct DayPartPlanner: Sendable {
    func dayPart(for date: Date, calendar: Calendar = .current) -> DayPart {
        let hour = calendar.component(.hour, from: date)
        if (5...11).contains(hour) { return .morning }
        if (12...17).contains(hour) { return .afternoon }
        return .evening
    }

    func proposal(now: Date = .now, calendar: Calendar = .current, activeCapsule: RecoveryCapsuleModel?, recentSteps: [NextStepModel], language: String) -> NextStepProposal {
        let zh = language.lowercased().hasPrefix("zh")
        let part = dayPart(for: now, calendar: calendar)
        let source = activeCapsule?.resumeProposal ?? recentSteps.first(where: { $0.status != .completed })?.proposal
        let category = source?.category ?? .other
        let sourceStep = source?.step
        switch part {
        case .morning:
            return NextStepProposal(title: zh ? "今天先开始这一点" : "Start this first today", step: sourceStep.map { zh ? "只做这个最小开头：\($0)" : "Do the smallest start of this: \($0)" } ?? (zh ? "打开一个需要处理的地方，看到第一项就停。" : "Open one place that needs attention and stop when the first item is visible."), timerMinutes: 5, stopCondition: zh ? "看到第一项就停。" : "Stop when the first item is visible.", category: category, shrinkLevel: .two, generatedBy: .localTemplate, whyThisStep: zh ? "早上只选一个入口，不做今日清单。" : "Morning landing picks one doorway, not a day plan.")
        case .afternoon:
            return NextStepProposal(title: zh ? "现在只重启一小步" : "Restart one small step now", step: sourceStep.map { zh ? "只重启这一步的开头：\($0)" : "Restart only the opening move: \($0)" } ?? (zh ? "选一个最容易打开的入口，做 5 分钟。" : "Pick the easiest doorway and give it 5 minutes."), timerMinutes: 5, stopCondition: zh ? "5 分钟到就停。" : "Stop at 5 minutes.", category: category, shrinkLevel: .two, generatedBy: .localTemplate, whyThisStep: zh ? "下午只恢复动能。" : "Afternoon mode restores motion only.")
        case .evening:
            return NextStepProposal(title: zh ? "今晚救回 3 分钟" : "Evening 3-minute rescue", step: sourceStep.map { zh ? "只做 3 分钟版本：\($0)" : "Do the 3-minute version: \($0)" } ?? (zh ? "把一个东西放到明早能看到的位置。" : "Put one needed item where tomorrow-you can see it."), timerMinutes: 3, stopCondition: zh ? "3 分钟到就停，开始过就算。" : "Stop at 3 minutes. Starting counts.", category: category, shrinkLevel: .three, generatedBy: .localTemplate, whyThisStep: zh ? "这是温和收尾，不是补打卡。" : "A gentle close, not streak repair.")
        }
    }
}

struct FrictionMemorySignal: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var category: TaskCategory
    var preset: FrictionPreset
    var createdAt: Date

    init(id: UUID = UUID(), category: TaskCategory, preset: FrictionPreset, createdAt: Date = .now) {
        self.id = id
        self.category = category
        self.preset = preset
        self.createdAt = createdAt
    }
}

@MainActor
final class FrictionMemoryStore: ObservableObject {
    @Published private(set) var signals: [FrictionMemorySignal]
    private let defaults: UserDefaults
    private let key = "sk_friction_memory_signals"
    private let limit = 80

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.signals = Self.load(defaults: defaults, key: key)
    }

    @discardableResult
    func record(category: TaskCategory, preset: FrictionPreset, at date: Date = .now) -> FrictionMemorySignal {
        let signal = FrictionMemorySignal(category: category, preset: preset, createdAt: date)
        signals.insert(signal, at: 0)
        signals = Array(signals.prefix(limit))
        persist()
        return signal
    }

    func topPreset(for category: TaskCategory, days: Int = 30, now: Date = .now) -> FrictionPreset? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let counts = signals.filter { $0.category == category && $0.createdAt >= start }.reduce(into: [FrictionPreset: Int]()) { partial, signal in
            partial[signal.preset, default: 0] += 1
        }
        return counts.sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value }.first?.key
    }

    func proposal(for category: TaskCategory, language: String) -> NextStepProposal? {
        guard let preset = topPreset(for: category) else { return nil }
        return FrictionPresetPlanner().proposal(for: preset, category: category, language: language)
    }

    func clear() { signals = []; persist() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(signals) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> [FrictionMemorySignal] {
        guard let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([FrictionMemorySignal].self, from: data) else { return [] }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }
}

struct FrictionForecast: Equatable, Sendable {
    let preset: FrictionPreset
    let category: TaskCategory
    let reason: String
    let proposal: NextStepProposal
}

struct FrictionForecastPlanner: Sendable {
    func forecast(text: String, category: TaskCategory? = nil, memory: [FrictionMemorySignal] = [], language: String = "en") -> FrictionForecast? {
        let zh = language.lowercased().hasPrefix("zh")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hint = textHint(in: trimmed.lowercased()) {
            return FrictionForecast(
                preset: hint.preset,
                category: category ?? .other,
                reason: zh ? hint.reasonZH : hint.reasonEN,
                proposal: FrictionPresetPlanner().proposal(for: hint.preset, category: category ?? .other, language: language)
            )
        }
        guard let preset = topPreset(in: memory, matching: category) else { return nil }
        return FrictionForecast(
            preset: preset,
            category: category ?? .other,
            reason: zh ? Self.memoryReasonZH : Self.memoryReasonEN,
            proposal: FrictionPresetPlanner().proposal(for: preset, category: category ?? .other, language: language)
        )
    }

    private func textHint(in lowercased: String) -> TextHint? {
        Self.textHints.first { hint in hint.keywords.contains { lowercased.contains($0) } }
    }

    private func topPreset(in memory: [FrictionMemorySignal], matching category: TaskCategory?) -> FrictionPreset? {
        var pool = memory
        if let category {
            let scoped = memory.filter { $0.category == category }
            if !scoped.isEmpty { pool = scoped }
        }
        guard !pool.isEmpty else { return nil }
        let counts = pool.reduce(into: [FrictionPreset: Int]()) { partial, signal in
            partial[signal.preset, default: 0] += 1
        }
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
        }.first?.key
    }

    private struct TextHint: Sendable {
        let preset: FrictionPreset
        let keywords: [String]
        let reasonEN: String
        let reasonZH: String
    }

    private static let textHints: [TextHint] = [
        TextHint(preset: .needLogin, keywords: ["login", "log in", "password", "登录", "密码"], reasonEN: "Login or password access seems to be the blocker.", reasonZH: "看起来是登录或密码信息卡住了你。"),
        TextHint(preset: .tooManyTabs, keywords: ["too big", "too much", "overwhelmed", "太大", "太多", "过载"], reasonEN: "It feels like too much at once, so the plan shrinks to one small thing.", reasonZH: "感觉一下子太多，先缩成一件小事。"),
        TextHint(preset: .tooVague, keywords: ["unclear", "vague", "don't know where", "不知道从哪", "不清楚"], reasonEN: "The next step sounds vague, so it becomes one concrete action.", reasonZH: "下一步听起来不太清楚，先把它变成一句具体动作。"),
        TextHint(preset: .needAnotherPerson, keywords: ["waiting", "need reply", "等回复", "等人回复"], reasonEN: "You're waiting on someone, so the next step is one small ask.", reasonZH: "你在等别人，下一步变成一个小的请求。"),
        TextHint(preset: .tooManyTabs, keywords: ["no energy", "tired", "没精力", "累了", "疲惫"], reasonEN: "You mentioned low energy, so the plan starts even smaller.", reasonZH: "你提到没精力，把开始缩得更小。")
    ]

    private static let memoryReasonEN = "Based on how you've restarted this kind of task before."
    private static let memoryReasonZH = "根据这类任务以前顺利重启的方式。"
}

struct StartScript: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var category: TaskCategory
    var createdAt: Date

    init(id: UUID = UUID(), title: String, body: String, category: TaskCategory, createdAt: Date = .now) {
        self.id = id
        self.title = String(title.prefix(80))
        self.body = String(body.prefix(400))
        self.category = category
        self.createdAt = createdAt
    }
}

@MainActor
final class StartScriptStore: ObservableObject {
    @Published private(set) var scripts: [StartScript]
    private let defaults: UserDefaults
    private let key = "sk_start_scripts"
    private let limit = 30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.scripts = Self.load(defaults: defaults, key: key)
    }

    @discardableResult
    func add(title: String, body: String, category: TaskCategory, at date: Date = .now) -> StartScript {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = scripts.first(where: { $0.title.caseInsensitiveCompare(cleanTitle) == .orderedSame && $0.body == cleanBody && $0.category == category }) { return existing }
        let script = StartScript(title: cleanTitle.isEmpty ? cleanBody : cleanTitle, body: cleanBody, category: category, createdAt: date)
        scripts.insert(script, at: 0)
        scripts = Array(scripts.prefix(limit))
        persist()
        return script
    }

    func delete(id: UUID) { scripts.removeAll { $0.id == id }; persist() }
    func recent(limit: Int = 6) -> [StartScript] { Array(scripts.sorted { $0.createdAt > $1.createdAt }.prefix(limit)) }

    func proposal(from script: StartScript, language: String) -> NextStepProposal {
        let zh = language.lowercased().hasPrefix("zh")
        return NextStepProposal(title: script.title, step: script.body, timerMinutes: 5, stopCondition: zh ? "5 分钟到就停。" : "Stop at 5 minutes.", category: script.category, shrinkLevel: .two, generatedBy: .user, whyThisStep: zh ? "这是你保存过的启动脚本。" : "This is one of your saved start scripts.")
    }

    func clear() { scripts = []; persist() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> [StartScript] {
        guard let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([StartScript].self, from: data) else { return [] }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }
}

struct CalendarSoftLandingEvent: Equatable, Sendable {
    var title: String
    var startDate: Date
}

struct CalendarSoftLandingPlanner: Sendable {
    func proposal(for event: CalendarSoftLandingEvent, now: Date = .now, language: String) -> NextStepProposal? {
        guard event.startDate >= now, let latest = Calendar.current.date(byAdding: .day, value: 7, to: now), event.startDate <= latest else { return nil }
        let text = event.title.lowercased()
        let zh = language.lowercased().hasPrefix("zh")
        let category: TaskCategory
        let title: String
        let step: String
        if text.contains("bill") || text.contains("账单") {
            category = .bills; title = zh ? "为账单先找入口" : "Prep the bill doorway"; step = zh ? "只打开账单或邮件，找到金额/截止日期就停。" : "Open the bill or email and stop when amount or due date is visible."
        } else if text.contains("doctor") || text.contains("dentist") || text.contains("医生") {
            category = .medical; title = zh ? "为预约确认一个细节" : "Confirm one appointment detail"; step = zh ? "只确认地址、时间或需要带的一个东西。" : "Confirm only the address, time, or one thing to bring."
        } else if text.contains("deadline") || text.contains("interview") || text.contains("meeting") || text.contains("会议") || text.contains("截止") {
            category = .workAdmin; title = zh ? "为日程准备一个开头" : "Prep one work doorway"; step = zh ? "只打开相关页面或文件，看到第一项就停。" : "Open the related page or file and stop when the first item is visible."
        } else if text.contains("appointment") || text.contains("call") || text.contains("预约") {
            category = .appointments; title = zh ? "为预约做 5 分钟准备" : "Prep the appointment for 5 minutes"; step = zh ? "只确认时间和入口，不处理全部。" : "Confirm the time and entry point, not the whole thing."
        } else { return nil }
        return NextStepProposal(title: title, step: step, timerMinutes: 5, stopCondition: zh ? "确认一个细节就停。" : "Stop after confirming one detail.", category: category, shrinkLevel: .two, generatedBy: .localTemplate, whyThisStep: zh ? "日历只变成一个准备动作。" : "Calendar soft landing turns the event into one prep action.")
    }
}

struct GentleReviewSummary: Equatable, Sendable {
    var startsThisWeek: Int
    var mostCommonFriction: FrictionPreset?
    var bestWindow: String?
    var message: String
}

struct GentleReviewPlanner: Sendable {
    func summary(proofs: [ProofOfStartEvent], frictionSignals: [FrictionMemorySignal], samples: [CalibrationSample], now: Date = .now, language: String) -> GentleReviewSummary {
        let zh = language.lowercased().hasPrefix("zh")
        let start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let starts = proofs.filter { $0.createdAt >= start }.count
        let mostCommon = mostCommonPreset(in: frictionSignals.filter { $0.createdAt >= start })
        let window = bestWindow(in: samples)
        let message = starts > 0 ? (zh ? "这周你已经开始了 \(starts) 次。下次继续从最小入口开始。" : "You started \(starts) times this week. Keep using the smallest doorway.") : (zh ? "这周还没有记录开始。可以从 3 分钟版本开始。" : "No starts recorded this week. A 3-minute version is enough to begin.")
        return GentleReviewSummary(startsThisWeek: starts, mostCommonFriction: mostCommon, bestWindow: window, message: message)
    }

    private func mostCommonPreset(in signals: [FrictionMemorySignal]) -> FrictionPreset? {
        let counts = signals.reduce(into: [FrictionPreset: Int]()) { partial, signal in partial[signal.preset, default: 0] += 1 }
        return counts.sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value }.first?.key
    }

    private func bestWindow(in samples: [CalibrationSample]) -> String? {
        let counted = samples.filter { $0.countedTowardTime }
        guard counted.count >= 2 else { return nil }
        let buckets = counted.reduce(into: [String: Int]()) { partial, sample in
            let window = (5...11).contains(sample.startHour) ? "morning" : ((12...17).contains(sample.startHour) ? "afternoon" : "evening")
            partial[window, default: 0] += 1
        }
        return buckets.sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }.first?.key
    }
}

struct WidgetNextStepSnapshot: Codable, Equatable, Sendable {
    var title: String
    var step: String
    var deepLinkString: String
}

@MainActor
final class WidgetNextStepStore: ObservableObject {
    @Published private(set) var snapshot: WidgetNextStepSnapshot?
    private let defaults: UserDefaults
    private let key = "sk_widget_next_step"

    init(defaults: UserDefaults? = UserDefaults(suiteName: "group.ren.startkind")) {
        self.defaults = defaults ?? .standard
        self.snapshot = Self.load(defaults: self.defaults, key: key)
    }

    func load() -> WidgetNextStepSnapshot? { snapshot = Self.load(defaults: defaults, key: key); return snapshot }
    func save(proposal: NextStepProposal) {
        let value = WidgetNextStepSnapshot(title: proposal.title, step: proposal.step, deepLinkString: "startkind://start")
        snapshot = value
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
    func clear() { snapshot = nil; defaults.removeObject(forKey: key) }

    private static func load(defaults: UserDefaults, key: String) -> WidgetNextStepSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetNextStepSnapshot.self, from: data)
    }
}
