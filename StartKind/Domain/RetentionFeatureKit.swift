import Foundation
import Combine

enum EnergyLevel: String, Codable, CaseIterable, Sendable, Identifiable { case low, medium, wired, overwhelmed; var id: String { rawValue } }

enum FrictionPreset: String, Codable, CaseIterable, Sendable, Identifiable { case needLogin = "need_login"; case needDocument = "need_document"; case tooVague = "too_vague"; case tooManyTabs = "too_many_tabs"; case needAnotherPerson = "need_another_person"; var id: String { rawValue } }
struct EnergyMatcher: Sendable {
    func apply(_ proposal: NextStepProposal, energy: EnergyLevel, language: String) -> NextStepProposal {
        let lang = ContentLanguage(language)
        var result = proposal
        switch energy {
        case .low:
            result.timerMinutes = min(result.timerMinutes, 5)
            result.shrinkLevel = max(result.shrinkLevel, .two)
            result.title = lang.pick(
                en: "Low energy: start tiny",
                zh: "低能量：只开始一点",
                ja: "低エネルギー：ほんの少しだけ"
            )
            result.step = lang.pick(
                en: "Open only the needed place and stop when you see the first item.",
                zh: "只打开需要的地方，看到第一项就停。",
                ja: "必要な場所だけを開いて、最初のひとつが見えたら止めましょう。"
            )
            result.stopCondition = lang.pick(
                en: "Stop when the first item is visible.",
                zh: "看到第一项就停。",
                ja: "最初のひとつが見えたら止めましょう。"
            )
            result.whyThisStep = lang.pick(
                en: "Matched to low energy.",
                zh: "按低能量版本处理。",
                ja: "今の低めのエネルギーに合わせました。"
            )
        case .medium:
            result.timerMinutes = min(max(result.timerMinutes, 5), 12)
            result.whyThisStep = lang.pick(
                en: "Matched to steady energy.",
                zh: "按普通能量版本处理。",
                ja: "落ち着いたエネルギーに合わせました。"
            )
        case .wired:
            result.timerMinutes = min(max(result.timerMinutes, 5), 10)
            result.step = lang.pick(
                en: "Set one clear boundary, then do: \(proposal.step)",
                zh: "先设一个清楚边界，然后做：\(proposal.step)",
                ja: "先に区切りをひとつ決めてから、これをしましょう：\(proposal.step)"
            )
            result.stopCondition = lang.pick(
                en: "Stop when the boundary is reached.",
                zh: "边界到了就停。",
                ja: "決めた区切りに来たら止めましょう。"
            )
            result.whyThisStep = lang.pick(
                en: "Channels high energy into one bounded action.",
                zh: "把高能量限制在一个小动作里。",
                ja: "高ぶったエネルギーを、区切りのあるひとつの動きに向けます。"
            )
        case .overwhelmed:
            result.timerMinutes = 5
            result.shrinkLevel = max(result.shrinkLevel, .three)
            result.title = lang.pick(
                en: "Overwhelmed: lower friction",
                zh: "过载：只降低阻力",
                ja: "余裕がないとき：まず負担を減らす"
            )
            result.step = lang.pick(
                en: "Take one exhale, put the needed item within reach, then stop.",
                zh: "呼气一次，把需要的东西放到手边，然后停。",
                ja: "一度息を吐いて、必要なものを手の届くところに置いたら、そこで止めましょう。"
            )
            result.stopCondition = lang.pick(
                en: "Stop when the item is within reach.",
                zh: "东西到手边就停。",
                ja: "手元に置けたら止めましょう。"
            )
            result.whyThisStep = lang.pick(
                en: "When overwhelmed, reduce friction before asking for progress.",
                zh: "过载时先减少阻力，不要求完成。",
                ja: "余裕がないときは、進めることより先に負担を減らします。"
            )
        }
        return result
    }
}

struct FrictionPresetPlanner: Sendable {
    func proposal(for preset: FrictionPreset, category: TaskCategory = .other, language: String) -> NextStepProposal {
        let lang = ContentLanguage(language)
        let values = Self.values(for: preset, language: lang)
        return NextStepProposal(
            title: values.0,
            step: values.1,
            timerMinutes: 5,
            stopCondition: values.2,
            category: category,
            shrinkLevel: .three,
            generatedBy: .localTemplate,
            whyThisStep: lang.pick(
                en: "This preset only lowers the starting friction.",
                zh: "这是一个阻力预设，只负责重新开始。",
                ja: "これは始めるときの負担を下げるためのものです。"
            )
        )
    }

    /// (title, step, stopCondition) for each preset, per content language.
    private static func values(
        for preset: FrictionPreset,
        language: ContentLanguage
    ) -> (String, String, String) {
        switch preset {
        case .needLogin:
            switch language {
            case .en:
                return ("Find the login", "Open the login page and only find the password or reset path. Stop there.", "Stop when the login or reset path is visible.")
            case .zhHans:
                return ("只找登录方式", "打开登录页，只找密码或重置入口，找到就停。", "找到登录或重置入口就停。")
            case .ja:
                return ("ログイン方法を見つける", "ログインページを開いて、パスワードか再設定の入り口だけを探しましょう。見つかったら止めて大丈夫です。", "ログインか再設定の入り口が見えたら止めましょう。")
            }
        case .needDocument:
            switch language {
            case .en:
                return ("Find one document", "Find one related document or email. Stop when you see its name.", "Stop when one document name is visible.")
            case .zhHans:
                return ("只找一个文件", "只找一个相关文件或邮件，看到文件名就停。", "看到文件名就停。")
            case .ja:
                return ("書類をひとつ見つける", "関係する書類かメールをひとつだけ探しましょう。名前が見えたら止めて大丈夫です。", "書類の名前がひとつ見えたら止めましょう。")
            }
        case .tooVague:
            switch language {
            case .en:
                return ("Write one verb", "Rewrite this as one action that starts with a verb. Stop after one sentence.", "Stop after one action sentence.")
            case .zhHans:
                return ("写下一句动词", "把这件事改写成一个动词开头的动作。写完就停。", "写出一句动作就停。")
            case .ja:
                return ("動詞をひとつ書く", "このことを、動詞から始まる動作ひとつに書き直しましょう。一文書けたら止めて大丈夫です。", "動作の一文が書けたら止めましょう。")
            }
        case .tooManyTabs:
            switch language {
            case .en:
                return ("Keep one tab", "Pick the one most relevant tab and ignore the rest for now. Stop after choosing.", "Stop after one tab is chosen.")
            case .zhHans:
                return ("只保留一个标签页", "选一个最相关的标签页，其他先不处理。选好就停。", "选好一个标签页就停。")
            case .ja:
                return ("タブをひとつだけ残す", "いちばん関係のあるタブをひとつ選んで、ほかは今は置いておきましょう。選べたら止めて大丈夫です。", "タブをひとつ選べたら止めましょう。")
            }
        case .needAnotherPerson:
            switch language {
            case .en:
                return ("Send one ask", "Write one message with one ask, without explaining the whole situation.", "Stop after drafting or sending one ask.")
            case .zhHans:
                return ("只发一条求助信息", "写一条只包含一个问题的信息，先不解释全部背景。", "写出或发出一条信息就停。")
            case .ja:
                return ("お願いをひとつ送る", "お願いをひとつだけ書いたメッセージを作りましょう。事情を全部説明しなくて大丈夫です。", "お願いを一件書くか送ったら止めましょう。")
            }
        }
    }
}

struct ProofOfStartEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var stepId: UUID?
    var title: String
    var category: TaskCategory
    var createdAt: Date

    init(id: UUID = UUID(), stepId: UUID? = nil, title: String, category: TaskCategory, createdAt: Date = .now) {
        self.id = id
        self.stepId = stepId
        self.title = title
        self.category = category
        self.createdAt = createdAt
    }
}

@MainActor
final class ProofOfStartStore: ObservableObject {
    @Published private(set) var events: [ProofOfStartEvent]
    private let defaults: UserDefaults
    private let key = "sk_proof_of_start_events"
    private let limit = 30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.events = Self.load(defaults: defaults, key: key)
    }

    @discardableResult
    func record(stepId: UUID?, title: String, category: TaskCategory, at date: Date = .now) -> ProofOfStartEvent {
        if let stepId, let existing = events.first(where: { $0.stepId == stepId }) {
            return existing
        }
        let event = ProofOfStartEvent(stepId: stepId, title: String(title.prefix(120)), category: category, createdAt: date)
        events.insert(event, at: 0)
        events = Array(events.prefix(limit))
        persist()
        return event
    }

    func recentCount(days: Int = 7, now: Date = .now) -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return events.filter { $0.createdAt >= start }.count
    }

    func clear() { events = []; persist() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> [ProofOfStartEvent] {
        guard let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([ProofOfStartEvent].self, from: data) else { return [] }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }
}

struct TinyAdminInboxItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var rawText: String
    var proposal: NextStepProposal
    var createdAt: Date

    init(id: UUID = UUID(), rawText: String, proposal: NextStepProposal, createdAt: Date = .now) {
        self.id = id
        self.rawText = String(rawText.prefix(2_000))
        self.proposal = proposal
        self.createdAt = createdAt
    }
}

@MainActor
final class TinyAdminInboxStore: ObservableObject {
    @Published private(set) var items: [TinyAdminInboxItem]
    private let defaults: UserDefaults
    private let key = "sk_tiny_admin_inbox_items"
    private let limit = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(defaults: defaults, key: key)
    }

    @discardableResult
    func add(rawText: String, proposal: NextStepProposal) -> TinyAdminInboxItem {
        let item = TinyAdminInboxItem(rawText: rawText, proposal: proposal)
        items.insert(item, at: 0)
        items = Array(items.prefix(limit))
        persist()
        return item
    }

    func clear() { items = []; persist() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> [TinyAdminInboxItem] {
        guard let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([TinyAdminInboxItem].self, from: data) else { return [] }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }
}

struct YesterdayRescuePlanner: Sendable {
    func proposal(activeCapsule: RecoveryCapsuleModel?, recentSteps: [NextStepModel], now: Date = .now, language: String) -> NextStepProposal? {
        let lang = ContentLanguage(language)
        if let activeCapsule { return restart(from: activeCapsule.resumeProposal, language: lang) }
        let calendar = Calendar.current
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return nil }
        let todayStart = calendar.startOfDay(for: now)
        let candidate = recentSteps
            .filter { $0.createdAt >= yesterdayStart && $0.createdAt < todayStart && $0.status != .completed }
            .sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
            .first
        guard let candidate else { return nil }
        return restart(from: candidate.proposal, language: lang)
    }

    private func restart(from proposal: NextStepProposal, language: ContentLanguage) -> NextStepProposal {
        NextStepProposal(
            title: language.pick(
                en: "Yesterday's thing: 3-minute version",
                zh: "昨天那件事：3 分钟版本",
                ja: "昨日のあれを、3分だけ"
            ),
            step: language.pick(
                en: "Do only the smallest start of this step: \(proposal.step)",
                zh: "只做这一步的最小开头：\(proposal.step)",
                ja: "この一歩の、いちばん小さな始まりだけをやりましょう：\(proposal.step)"
            ),
            timerMinutes: 3,
            stopCondition: language.pick(
                en: "Stop at 3 minutes. Starting counts.",
                zh: "3 分钟到就停，开始过就算。",
                ja: "3分たったら止めましょう。始められたら、それで十分です。"
            ),
            category: proposal.category,
            shrinkLevel: max(proposal.shrinkLevel, .two),
            generatedBy: .localTemplate,
            whyThisStep: language.pick(
                en: "This is a gentle restart, not a streak repair.",
                zh: "这是温和恢复，不是补打卡。",
                ja: "これはやさしい再開です。連続記録を埋めるためのものではありません。"
            )
        )
    }
}
