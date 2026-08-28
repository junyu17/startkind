import Foundation
import Combine

struct ResumeCardContext: Equatable, Sendable {
    let title: String
    let action: String
    let stopCondition: String
    let returnNote: String?
}

struct ResumeCardPlanner: Sendable {
    func context(for capsule: RecoveryCapsuleModel) -> ResumeCardContext {
        ResumeCardContext(
            title: capsule.resumeTitle,
            action: capsule.resumeStepText,
            stopCondition: capsule.resumeStopCondition,
            returnNote: capsule.returnNote
        )
    }
}

struct StartLadderPlanner: Sendable {
    static let minutes = [2, 5, 15]

    func proposal(from source: NextStepProposal, minutes: Int, language: String) -> NextStepProposal {
        let selected = Self.minutes.contains(minutes) ? minutes : 5
        let zh = language.lowercased().hasPrefix("zh")
        let title = zh ? "\(selected) 分钟开始：\(source.title)" : "\(selected)-minute start: \(source.title)"
        let step = zh ? "接下来的 \(selected) 分钟，只做这一件事：\(source.step)" : "For the next \(selected) minutes, do only this: \(source.step)"
        let stop = zh ? "\(selected) 分钟到就停，不需要决定下一步。" : "Stop at \(selected) minutes. You do not need to decide what comes next."
        return NextStepProposal(
            title: title,
            step: step,
            timerMinutes: selected,
            stopCondition: stop,
            category: source.category,
            shrinkLevel: selected <= 5 ? max(source.shrinkLevel, .two) : source.shrinkLevel,
            generatedBy: .localTemplate,
            whyThisStep: zh ? "你选择了一个可承受的开始时长。" : "You chose a start length that fits right now."
        )
    }
}

enum ActionPrepKind: String, Codable, Sendable {
    case email, phone, website, appointment, document, instruction
}

struct ActionPrepPlan: Equatable, Sendable {
    let kind: ActionPrepKind
    let label: String
    let instruction: String
    let url: URL?
}

struct ActionPrepPlanner: Sendable {
    func plan(for proposal: NextStepProposal, language: String) -> ActionPrepPlan? {
        let text = "\(proposal.title) \(proposal.step)"
        let zh = language.lowercased().hasPrefix("zh")
        if let email = firstEmail(in: text), let url = URL(string: "mailto:\(email)") {
            return ActionPrepPlan(kind: .email, label: zh ? "准备一封邮件" : "Prepare an email", instruction: zh ? "将打开邮件草稿，不会自动发送。" : "This opens a draft. Nothing is sent automatically.", url: url)
        }
        if let phone = firstPhone(in: text), let url = URL(string: "tel:\(phone)") {
            return ActionPrepPlan(kind: .phone, label: zh ? "准备拨号" : "Prepare a call", instruction: zh ? "将打开电话；由你决定是否拨出。" : "This opens Phone. You decide whether to place the call.", url: url)
        }
        if let url = firstURL(in: text) {
            return ActionPrepPlan(kind: .website, label: zh ? "打开相关网站" : "Open the related site", instruction: zh ? "网站已准备好；由你决定是否继续。" : "The site is ready. You decide whether to continue.", url: url)
        }
        let lower = text.lowercased()
        if proposal.category == .appointments || lower.contains("appointment") || lower.contains("预约") || lower.contains("calendar") || lower.contains("日历") {
            return ActionPrepPlan(kind: .appointment, label: zh ? "准备预约入口" : "Prepare the appointment", instruction: zh ? "先确认时间、地点或联系方式中的一项。" : "Confirm one thing: the time, place, or contact method.", url: nil)
        }
        if lower.contains("document") || lower.contains("form") || lower.contains("file") || lower.contains("文件") || lower.contains("表格") {
            return ActionPrepPlan(kind: .document, label: zh ? "准备文件入口" : "Prepare the document", instruction: zh ? "先找到文件名或表格入口，不需要填写。" : "Find the document or form first; you do not need to fill it out yet.", url: nil)
        }
        return ActionPrepPlan(kind: .instruction, label: zh ? "准备开始环境" : "Prepare your starting place", instruction: zh ? "只打开完成这一步需要的第一个应用或页面。" : "Open only the first app or page this step needs.", url: nil)
    }

    private func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url
    }

    private func firstEmail(in text: String) -> String? {
        let pattern = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func firstPhone(in text: String) -> String? {
        let pattern = "(?:\\+?1[ .-]?)?(?:\\(?[0-9]{3}\\)?[ .-]?)?[0-9]{3}[ .-][0-9]{4}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), let swiftRange = Range(match.range, in: text) else { return nil }
        let digits = String(text[swiftRange]).filter(\.isNumber)
        return digits.count >= 7 ? digits : nil
    }
}

enum DailyOneThingSource: String, Codable, Sendable {
    case recovery, admin, vault
}

struct DailyOneThingCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let proposal: NextStepProposal
    let source: DailyOneThingSource
}

struct DailyOneThing: Codable, Equatable, Sendable {
    let dayKey: String
    let candidateID: UUID
    let proposal: NextStepProposal
    let source: DailyOneThingSource
}

struct DailyOneThingPlanner: Sendable {
    func choose(from candidates: [DailyOneThingCandidate], date: Date = .now, calendar: Calendar = .current) -> DailyOneThing? {
        guard let candidate = candidates.sorted(by: rank).first else { return nil }
        return DailyOneThing(dayKey: dayKey(for: date, calendar: calendar), candidateID: candidate.id, proposal: candidate.proposal, source: candidate.source)
    }

    func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func rank(_ lhs: DailyOneThingCandidate, _ rhs: DailyOneThingCandidate) -> Bool {
        let weight: [DailyOneThingSource: Int] = [.recovery: 0, .admin: 1, .vault: 2]
        if weight[lhs.source, default: 9] != weight[rhs.source, default: 9] {
            return weight[lhs.source, default: 9] < weight[rhs.source, default: 9]
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

@MainActor
final class DailyOneThingStore: ObservableObject {
    @Published private(set) var item: DailyOneThing?
    private let defaults: UserDefaults
    private let key = "sk_daily_one_thing"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.item = Self.load(defaults: defaults, key: key)
    }

    func item(for date: Date = .now, planner: DailyOneThingPlanner = DailyOneThingPlanner()) -> DailyOneThing? {
        guard item?.dayKey == planner.dayKey(for: date) else { return nil }
        return item
    }

    @discardableResult
    func select(from candidates: [DailyOneThingCandidate], date: Date = .now, planner: DailyOneThingPlanner = DailyOneThingPlanner()) -> DailyOneThing? {
        if let current = item(for: date, planner: planner) { return current }
        item = planner.choose(from: candidates, date: date)
        persist()
        return item
    }

    @discardableResult
    func replace(from candidates: [DailyOneThingCandidate], date: Date = .now, planner: DailyOneThingPlanner = DailyOneThingPlanner()) -> DailyOneThing? {
        let alternatives = candidates.filter { $0.id != item?.candidateID }
        item = planner.choose(from: alternatives, date: date)
        persist()
        return item
    }

    func dismiss() { item = nil; defaults.removeObject(forKey: key) }
    func clear() { dismiss() }

    private func persist() {
        guard let item, let data = try? JSONEncoder().encode(item) else { defaults.removeObject(forKey: key); return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> DailyOneThing? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DailyOneThing.self, from: data)
    }
}

struct StartProfile: Equatable, Sendable {
    let sampleCount: Int
    let preferredWindow: DayPart?
    let helpfulMinutes: Int?
    let productiveCategory: TaskCategory?
}

struct StartProfilePlanner: Sendable {
    func profile(samples: [CalibrationSample]) -> StartProfile {
        let useful = samples.filter { $0.countedTowardTime }
        let preferredWindow = commonWindow(in: useful)
        let helpfulMinutes = medianMinutes(in: useful)
        let productiveCategory = commonCategory(in: useful.filter { $0.outcome == .completed || $0.outcome == .partial })
        return StartProfile(sampleCount: samples.count, preferredWindow: preferredWindow, helpfulMinutes: helpfulMinutes, productiveCategory: productiveCategory)
    }

    private func commonWindow(in samples: [CalibrationSample]) -> DayPart? {
        guard samples.count >= 3 else { return nil }
        let counts = Dictionary(grouping: samples.map { DayPartPlanner().dayPart(for: hourDate($0.startHour), calendar: utcCalendar) }, by: { $0 }).mapValues(\.count)
        return counts.max { lhs, rhs in lhs.value == rhs.value ? lhs.key.rawValue > rhs.key.rawValue : lhs.value < rhs.value }?.key
    }

    private func medianMinutes(in samples: [CalibrationSample]) -> Int? {
        let values = samples.map(\.actualMinutes).filter { $0 > 0 }.sorted()
        guard !values.isEmpty else { return nil }
        let index = values.count / 2
        let median = values.count.isMultiple(of: 2) ? (values[index - 1] + values[index]) / 2 : values[index]
        return min(25, max(2, Int(median.rounded())))
    }

    private func commonCategory(in samples: [CalibrationSample]) -> TaskCategory? {
        var counts: [TaskCategory: Int] = [:]
        for sample in samples {
            counts[sample.category, default: 0] += 1
        }
        return counts.sorted {
            $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value
        }.first?.key
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func hourDate(_ hour: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour)) ?? .now
    }
}

struct UrgentAdminSignal: Equatable, Sendable {
    let title: String
    let detail: String
    let proposal: NextStepProposal
}

struct UrgentAdminPlanner: Sendable {
    func signal(in text: String, category: TaskCategory? = nil, language: String) -> UrgentAdminSignal? {
        let lower = text.lowercased()
        let cues = ["urgent", "final notice", "past due", "due today", "deadline", "respond by", "overdue", "紧急", "最后通知", "已逾期", "今天到期", "截止", "请回复"]
        guard cues.contains(where: { lower.contains($0) }) else { return nil }
        let zh = language.lowercased().hasPrefix("zh")
        let selectedCategory = category ?? inferredCategory(in: lower)
        let proposal = NextStepProposal(
            title: zh ? "先联系原始发送方" : "Contact the original sender first",
            step: zh ? "打开原始信件、邮件或网站，只找到联系入口或回复按钮。" : "Open the original letter, email, or site and only find its contact or reply path.",
            timerMinutes: 5,
            stopCondition: zh ? "找到联系入口就停；是否联系由你决定。" : "Stop after finding the contact path. You decide whether to contact them.",
            category: selectedCategory,
            shrinkLevel: .two,
            generatedBy: .localTemplate,
            whyThisStep: zh ? "这看起来有时间提示；先找到原始联系人，不提供建议。" : "This appears time-sensitive. Start by finding the original contact; StartKind does not advise on the content."
        )
        return UrgentAdminSignal(title: zh ? "时间敏感" : "Time-sensitive", detail: zh ? "先找到原始发送方的联系入口。" : "Find the original sender's contact path first.", proposal: proposal)
    }

    private func inferredCategory(in text: String) -> TaskCategory {
        if text.contains("bill") || text.contains("payment") || text.contains("账单") || text.contains("付款") { return .bills }
        if text.contains("appointment") || text.contains("doctor") || text.contains("预约") || text.contains("医生") { return .appointments }
        if text.contains("insurance") || text.contains("保险") { return .insurance }
        return .other
    }
}

struct PreferredCoStarter: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var lastRoomCode: String?
    var savedAt: Date

    init(id: UUID = UUID(), displayName: String, lastRoomCode: String?, savedAt: Date = .now) {
        self.id = id
        self.displayName = String(displayName.prefix(40))
        self.lastRoomCode = lastRoomCode.map { String($0.prefix(6)) }
        self.savedAt = savedAt
    }
}

@MainActor
final class CoStartContinuityStore: ObservableObject {
    @Published private(set) var preferred: PreferredCoStarter?
    private let defaults: UserDefaults
    private let key = "sk_preferred_costarter"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preferred = Self.load(defaults: defaults, key: key)
    }

    func save(displayName: String, roomCode: String?) {
        let clean = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        preferred = PreferredCoStarter(displayName: clean, lastRoomCode: roomCode)
        persist()
    }

    func clear() { preferred = nil; defaults.removeObject(forKey: key) }

    private func persist() {
        guard let preferred, let data = try? JSONEncoder().encode(preferred) else { defaults.removeObject(forKey: key); return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> PreferredCoStarter? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PreferredCoStarter.self, from: data)
    }
}
