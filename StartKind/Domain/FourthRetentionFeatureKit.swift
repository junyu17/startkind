import Foundation
import Combine

struct EmergencyTinyModePlanner: Sendable {
    func detectsTrigger(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["too much", "overwhelmed", "cannot start", "can't start", "i am a mess", "i'm a mess", "一团乱", "太乱", "崩溃", "ぐちゃぐちゃ", "いっぱいいっぱい", "手につかない", "始められない", "もう無理", "余裕がない"].contains { lower.contains($0) }
    }

    func proposal(language: String) -> NextStepProposal {
        let lang = ContentLanguage(language)
        return NextStepProposal(
            title: lang.pick(
                en: "Emergency 3-minute mode",
                zh: "紧急 3 分钟模式",
                zhHant: "緊急 3 分鐘模式",
                ja: "緊急の3分モード",
                ko: "긴급 3분 모드"
            ),
            step: lang.pick(
                en: "Take one exhale. Put one needed thing within reach, then stop.",
                zh: "呼气一次。只把一个需要的东西放到手边，然后停。",
                zhHant: "呼氣一次。只把一個需要的東西放到手邊，然後停。",
                ja: "一度息を吐きましょう。必要なものをひとつ手の届くところに置いたら、そこで止めます。",
                ko: "숨을 한 번 내쉬세요. 필요한 것 하나를 손 닿는 곳에 두고 멈춰요."
            ),
            timerMinutes: 3,
            stopCondition: lang.pick(
                en: "Stop when one thing is within reach.",
                zh: "东西到手边就停。",
                zhHant: "東西到手邊就停。",
                ja: "ひとつ手元に置けたら止めましょう。",
                ko: "하나를 손 닿는 곳에 뒀으면 멈춰요."
            ),
            category: .other,
            shrinkLevel: .three,
            generatedBy: .localTemplate,
            whyThisStep: lang.pick(
                en: "When overloaded, lower friction first.",
                zh: "过载时先降低阻力。",
                zhHant: "過載時先降低阻力。",
                ja: "余裕がないときは、まず負担を下げます。",
                ko: "여유가 없을 땐 부담부터 낮춰요."
            )
        )
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
        let lang = ContentLanguage(language)
        switch self {
        case .emergencyTiny:
            return EmergencyTinyModePlanner().proposal(language: language)
        case .stuck:
            return FrictionPresetPlanner().proposal(for: .tooVague, category: .other, language: language)
        case .startFive:
            return NextStepProposal(
                title: lang.pick(
                    en: "Start for 5 minutes",
                    zh: "开始 5 分钟",
                    zhHant: "開始 5 分鐘",
                    ja: "5分だけ始める",
                    ko: "5분만 시작하기"
                ),
                step: lang.pick(
                    en: "Open the easiest doorway and work for 5 minutes.",
                    zh: "打开最容易开始的地方，做 5 分钟。",
                    zhHant: "開啟最容易開始的地方，做 5 分鐘。",
                    ja: "いちばん開きやすい入り口を開いて、5分だけ進めましょう。",
                    ko: "가장 들어가기 쉬운 곳을 열고 5분만 해 보세요."
                ),
                timerMinutes: 5,
                stopCondition: lang.pick(
                    en: "Stop at 5 minutes.",
                    zh: "5 分钟到就停。",
                    zhHant: "5 分鐘到就停。",
                    ja: "5分たったら止めましょう。",
                    ko: "5분이 되면 멈춰요."
                ),
                category: .other,
                shrinkLevel: .two,
                generatedBy: .localTemplate,
                whyThisStep: lang.pick(
                    en: "Home screen quick start.",
                    zh: "主屏幕快捷启动。",
                    zhHant: "主螢幕快捷啟動。",
                    ja: "ホーム画面からのクイックスタートです。",
                    ko: "홈 화면에서 바로 시작해요."
                )
            )
        case .rescueYesterday:
            return NextStepProposal(
                title: lang.pick(
                    en: "Rescue yesterday for 3 minutes",
                    zh: "救回昨天 3 分钟",
                    zhHant: "救回昨天 3 分鐘",
                    ja: "昨日のことを3分だけ救う",
                    ko: "어제 일 3분만 구하기"
                ),
                step: lang.pick(
                    en: "Do only the smallest start of yesterday's thing.",
                    zh: "只做昨天那件事的最小开头。",
                    zhHant: "只做昨天那件事的最小開頭。",
                    ja: "昨日のあれの、いちばん小さな始まりだけをやりましょう。",
                    ko: "어제 하려던 일의 가장 작은 시작만 해 보세요."
                ),
                timerMinutes: 3,
                stopCondition: lang.pick(
                    en: "Starting counts.",
                    zh: "开始过就算。",
                    zhHant: "開始過就算。",
                    ja: "始められたら、それで十分です。",
                    ko: "시작한 것만으로 충분해요."
                ),
                category: .other,
                shrinkLevel: .three,
                generatedBy: .localTemplate,
                whyThisStep: lang.pick(
                    en: "This is a gentle restart.",
                    zh: "这是温和恢复。",
                    zhHant: "這是溫和恢復。",
                    ja: "これはやさしい再開です。",
                    ko: "부드럽게 다시 시작하는 거예요."
                )
            )
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
        let lang = ContentLanguage(language)
        let part = dayPart(for: now, calendar: calendar)
        let source = activeCapsule?.resumeProposal ?? recentSteps.first(where: { $0.status != .completed })?.proposal
        let category = source?.category ?? .other
        let sourceStep = source?.step
        switch part {
        case .morning:
            return NextStepProposal(
                title: lang.pick(
                    en: "Start this first today",
                    zh: "今天先开始这一点",
                    zhHant: "今天先開始這一點",
                    ja: "今日はまず、ここから",
                    ko: "오늘은 이것부터 시작해요"
                ),
                step: sourceStep.map { source in
                    lang.pick(
                        en: "Do the smallest start of this: \(source)",
                        zh: "只做这个最小开头：\(source)",
                        zhHant: "只做這個最小開頭：\(source)",
                        ja: "これのいちばん小さな始まりだけをやりましょう：\(source)",
                        ko: "이 일의 가장 작은 시작만 해 보세요: \(source)"
                    )
                } ?? lang.pick(
                    en: "Open one place that needs attention and stop when the first item is visible.",
                    zh: "打开一个需要处理的地方，看到第一项就停。",
                    zhHant: "開啟一個需要處理的地方，看到第一項就停。",
                    ja: "気になっている場所をひとつ開いて、最初のひとつが見えたら止めましょう。",
                    ko: "신경 쓰이는 곳 하나를 열고, 첫 항목이 보이면 멈춰요."
                ),
                timerMinutes: 5,
                stopCondition: lang.pick(
                    en: "Stop when the first item is visible.",
                    zh: "看到第一项就停。",
                    zhHant: "看到第一項就停。",
                    ja: "最初のひとつが見えたら止めましょう。",
                    ko: "첫 항목이 보이면 멈춰요."
                ),
                category: category,
                shrinkLevel: .two,
                generatedBy: .localTemplate,
                whyThisStep: lang.pick(
                    en: "Morning landing picks one doorway, not a day plan.",
                    zh: "早上只选一个入口，不做今日清单。",
                    zhHant: "早上只選一個入口，不做今日清單。",
                    ja: "朝は入り口をひとつ選ぶだけにします。一日の計画は作りません。",
                    ko: "아침에는 시작할 곳 하나만 골라요. 하루 계획은 세우지 않아요."
                )
            )
        case .afternoon:
            return NextStepProposal(
                title: lang.pick(
                    en: "Restart one small step now",
                    zh: "现在只重启一小步",
                    zhHant: "現在只重啟一小步",
                    ja: "今、小さな一歩だけ再開する",
                    ko: "지금 작은 한 걸음만 다시 시작하기"
                ),
                step: sourceStep.map { source in
                    lang.pick(
                        en: "Restart only the opening move: \(source)",
                        zh: "只重启这一步的开头：\(source)",
                        zhHant: "只重啟這一步的開頭：\(source)",
                        ja: "出だしのところだけ、もう一度：\(source)",
                        ko: "첫 동작만 다시 해 보세요: \(source)"
                    )
                } ?? lang.pick(
                    en: "Pick the easiest doorway and give it 5 minutes.",
                    zh: "选一个最容易打开的入口，做 5 分钟。",
                    zhHant: "選一個最容易開啟的入口，做 5 分鐘。",
                    ja: "いちばん開きやすい入り口を選んで、5分だけ使いましょう。",
                    ko: "가장 들어가기 쉬운 곳을 골라 5분만 써 보세요."
                ),
                timerMinutes: 5,
                stopCondition: lang.pick(
                    en: "Stop at 5 minutes.",
                    zh: "5 分钟到就停。",
                    zhHant: "5 分鐘到就停。",
                    ja: "5分たったら止めましょう。",
                    ko: "5분이 되면 멈춰요."
                ),
                category: category,
                shrinkLevel: .two,
                generatedBy: .localTemplate,
                whyThisStep: lang.pick(
                    en: "Afternoon mode restores motion only.",
                    zh: "下午只恢复动能。",
                    zhHant: "下午只恢復動能。",
                    ja: "午後は動きを取り戻すだけにします。",
                    ko: "오후에는 다시 움직이는 것만 목표로 해요."
                )
            )
        case .evening:
            return NextStepProposal(
                title: lang.pick(
                    en: "Evening 3-minute rescue",
                    zh: "今晚救回 3 分钟",
                    zhHant: "今晚救回 3 分鐘",
                    ja: "夜の3分レスキュー",
                    ko: "저녁 3분 구하기"
                ),
                step: sourceStep.map { source in
                    lang.pick(
                        en: "Do the 3-minute version: \(source)",
                        zh: "只做 3 分钟版本：\(source)",
                        zhHant: "只做 3 分鐘版本：\(source)",
                        ja: "3分の版だけをやりましょう：\(source)",
                        ko: "3분짜리 버전만 해 보세요: \(source)"
                    )
                } ?? lang.pick(
                    en: "Put one needed item where tomorrow-you can see it.",
                    zh: "把一个东西放到明早能看到的位置。",
                    zhHant: "把一個東西放到明早能看到的位置。",
                    ja: "必要なものをひとつ、明日の自分が見える場所に置きましょう。",
                    ko: "필요한 물건 하나를 내일의 내가 볼 수 있는 곳에 두세요."
                ),
                timerMinutes: 3,
                stopCondition: lang.pick(
                    en: "Stop at 3 minutes. Starting counts.",
                    zh: "3 分钟到就停，开始过就算。",
                    zhHant: "3 分鐘到就停，開始過就算。",
                    ja: "3分たったら止めましょう。始められたら、それで十分です。",
                    ko: "3분이 되면 멈춰요. 시작한 것만으로 충분해요."
                ),
                category: category,
                shrinkLevel: .three,
                generatedBy: .localTemplate,
                whyThisStep: lang.pick(
                    en: "A gentle close, not streak repair.",
                    zh: "这是温和收尾，不是补打卡。",
                    zhHant: "這是溫和收尾，不是補打卡。",
                    ja: "やさしい締めくくりです。連続記録を埋めるためのものではありません。",
                    ko: "부드럽게 마무리하는 거예요. 연속 기록을 채우려는 게 아니에요."
                )
            )
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
        let lang = ContentLanguage(language)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hint = textHint(in: trimmed.lowercased()) {
            return FrictionForecast(
                preset: hint.preset,
                category: category ?? .other,
                reason: hint.reason(lang),
                proposal: FrictionPresetPlanner().proposal(for: hint.preset, category: category ?? .other, language: language)
            )
        }
        guard let preset = topPreset(in: memory, matching: category) else { return nil }
        return FrictionForecast(
            preset: preset,
            category: category ?? .other,
            reason: Self.memoryReason(lang),
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
        let reasonZHHant: String
        let reasonJA: String
        let reasonKO: String

        func reason(_ language: ContentLanguage) -> String {
            switch language {
            case .en: return reasonEN
            case .zhHans: return reasonZH
            case .zhHant: return reasonZHHant
            case .ja: return reasonJA
            case .ko: return reasonKO
            }
        }
    }

    private static let textHints: [TextHint] = [
        TextHint(preset: .needLogin, keywords: ["login", "log in", "password", "登录", "密码", "ログイン", "パスワード", "サインイン", "登入", "密碼", "로그인", "비밀번호", "패스워드"], reasonEN: "Login or password access seems to be the blocker.", reasonZH: "看起来是登录或密码信息卡住了你。", reasonZHHant: "看起來是登入或密碼資訊卡住了你。", reasonJA: "ログインかパスワードのところで止まっているようです。", reasonKO: "로그인이나 비밀번호 때문에 막혀 있는 것 같아요."),
        TextHint(preset: .tooManyTabs, keywords: ["too big", "too much", "overwhelmed", "太大", "太多", "过载", "多すぎ", "大きすぎ", "いっぱいいっぱい", "太大", "太多", "過載", "너무 커", "너무 많", "벅차", "버거"], reasonEN: "It feels like too much at once, so the plan shrinks to one small thing.", reasonZH: "感觉一下子太多，先缩成一件小事。", reasonZHHant: "感覺一下子太多，先縮成一件小事。", reasonJA: "一度に多すぎると感じているようなので、小さなことひとつに縮めます。", reasonKO: "한꺼번에 너무 많게 느껴지네요. 작은 일 하나로 줄여 볼게요."),
        TextHint(preset: .tooVague, keywords: ["unclear", "vague", "don't know where", "不知道从哪", "不清楚", "どこから", "わからない", "分からない", "曖昧", "不知道從哪", "不清楚", "막막", "어디서부터", "모르겠", "애매"], reasonEN: "The next step sounds vague, so it becomes one concrete action.", reasonZH: "下一步听起来不太清楚，先把它变成一句具体动作。", reasonZHHant: "下一步聽起來不太清楚，先把它變成一句具體動作。", reasonJA: "次の一歩がはっきりしないようなので、具体的な動作ひとつにします。", reasonKO: "다음 걸음이 막연하게 느껴지네요. 구체적인 동작 하나로 바꿔 볼게요."),
        TextHint(preset: .needAnotherPerson, keywords: ["waiting", "need reply", "等回复", "等人回复", "返事待ち", "返信待ち", "待っている", "連絡待ち", "等回覆", "等人回覆", "답장 기다", "답변 기다", "연락 기다", "회신 기다"], reasonEN: "You're waiting on someone, so the next step is one small ask.", reasonZH: "你在等别人，下一步变成一个小的请求。", reasonZHHant: "你在等別人，下一步變成一個小的請求。", reasonJA: "誰かの返事を待っているようなので、次の一歩は小さなお願いひとつにします。", reasonKO: "누군가를 기다리고 있네요. 다음 걸음은 작은 부탁 하나로 해 봐요."),
        TextHint(preset: .tooManyTabs, keywords: ["no energy", "tired", "没精力", "累了", "疲惫", "疲れた", "つかれた", "元気が出ない", "しんどい", "沒精力", "累了", "疲憊", "기운이 없", "힘이 없", "피곤", "지쳐", "지쳤"], reasonEN: "You mentioned low energy, so the plan starts even smaller.", reasonZH: "你提到没精力，把开始缩得更小。", reasonZHHant: "你提到沒精力，把開始縮得更小。", reasonJA: "元気が出ないとのことなので、始まりをもっと小さくします。", reasonKO: "기운이 없다고 하셨으니 시작을 더 작게 줄여 볼게요.")
    ]

    private static let memoryReasonEN = "Based on how you've restarted this kind of task before."
    private static let memoryReasonZH = "根据这类任务以前顺利重启的方式。"
    private static let memoryReasonJA = "この種のタスクを、以前どう再開できたかに基づいています。"
    private static let memoryReasonZHHant = "根據這類任務以前順利重啟的方式。"
    private static let memoryReasonKO = "이런 종류의 일을 예전에 어떻게 다시 시작했는지를 바탕으로 했어요."

    private static func memoryReason(_ language: ContentLanguage) -> String {
        switch language {
        case .en: return memoryReasonEN
        case .zhHans: return memoryReasonZH
        case .zhHant: return memoryReasonZHHant
        case .ja: return memoryReasonJA
        case .ko: return memoryReasonKO
        }
    }
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
        let lang = ContentLanguage(language)
        return NextStepProposal(
            title: script.title,
            step: script.body,
            timerMinutes: 5,
            stopCondition: lang.pick(
                en: "Stop at 5 minutes.",
                zh: "5 分钟到就停。",
                zhHant: "5 分鐘到就停。",
                ja: "5分たったら止めましょう。",
                ko: "5분이 되면 멈춰요."
            ),
            category: script.category,
            shrinkLevel: .two,
            generatedBy: .user,
            whyThisStep: lang.pick(
                en: "This is one of your saved start scripts.",
                zh: "这是你保存过的启动脚本。",
                zhHant: "這是你儲存過的啟動指令碼。",
                ja: "これは、あなたが保存した開始のひとつです。",
                ko: "저장해 둔 시작 방법 중 하나예요."
            )
        )
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
    func proposal(for event: CalendarSoftLandingEvent, now: Date = .now, calendar: Calendar = .current, language: String) -> NextStepProposal? {
        let eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventTitle.isEmpty else { return nil }
        let today = calendar.startOfDay(for: now)
        let eventDay = calendar.startOfDay(for: event.startDate)
        let latest = calendar.date(byAdding: .day, value: 7, to: today)
        guard let latest, eventDay >= today, eventDay <= latest else { return nil }
        let text = eventTitle.lowercased()
        let lang = ContentLanguage(language)
        let category: TaskCategory
        let title: String
        let step: String
        if text.contains("bill") || text.contains("账单") || text.contains("請求") || text.contains("支払") {
            category = .bills
            title = lang.pick(
                en: "Prep the bill doorway",
                zh: "为账单先找入口",
                zhHant: "為帳單先找入口",
                ja: "請求書の入り口を用意する",
                ko: "청구서 열어 볼 준비하기"
            )
            step = lang.pick(
                en: "Open the bill or email and stop when amount or due date is visible.",
                zh: "只打开账单或邮件，找到金额/截止日期就停。",
                zhHant: "只打開帳單或郵件，找到金額/截止日期就停。",
                ja: "請求書かメールを開いて、金額か支払期限が見えたら止めましょう。",
                ko: "청구서나 이메일을 열고, 금액이나 납부 기한이 보이면 멈춰요."
            )
        } else if text.contains("doctor") || text.contains("dentist") || text.contains("医生") || text.contains("医者") || text.contains("歯科") || text.contains("病院") {
            category = .medical
            title = lang.pick(
                en: "Confirm one appointment detail",
                zh: "为预约确认一个细节",
                zhHant: "為預約確認一個細節",
                ja: "予約の詳細をひとつ確かめる",
                ko: "예약 내용 하나 확인하기"
            )
            step = lang.pick(
                en: "Confirm only the address, time, or one thing to bring.",
                zh: "只确认地址、时间或需要带的一个东西。",
                zhHant: "只確認地址、時間或需要帶的一個東西。",
                ja: "場所か時間、持ち物のどれかひとつだけを確かめましょう。",
                ko: "장소, 시간, 챙길 것 중 하나만 확인해 보세요."
            )
        } else if text.contains("deadline") || text.contains("interview") || text.contains("meeting") || text.contains("会议") || text.contains("截止") || text.contains("会議") || text.contains("面接") || text.contains("締切") || text.contains("締め切り") {
            category = .workAdmin
            title = lang.pick(
                en: "Prep one work doorway",
                zh: "为日程准备一个开头",
                zhHant: "為日程準備一個開頭",
                ja: "仕事の入り口をひとつ用意する",
                ko: "업무 시작할 곳 하나 준비하기"
            )
            step = lang.pick(
                en: "Open the related page or file and stop when the first item is visible.",
                zh: "只打开相关页面或文件，看到第一项就停。",
                zhHant: "只打開相關頁面或檔案，看到第一項就停。",
                ja: "関係するページかファイルを開いて、最初のひとつが見えたら止めましょう。",
                ko: "관련 페이지나 파일을 열고, 첫 항목이 보이면 멈춰요."
            )
        } else if text.contains("appointment") || text.contains("call") || text.contains("预约") || text.contains("予約") || text.contains("打ち合わせ") {
            category = .appointments
            title = lang.pick(
                en: "Prep the appointment for 5 minutes",
                zh: "为预约做 5 分钟准备",
                zhHant: "為預約做 5 分鐘準備",
                ja: "予約の準備を5分だけ",
                ko: "예약 준비 5분만 하기"
            )
            step = lang.pick(
                en: "Confirm the time and entry point, not the whole thing.",
                zh: "只确认时间和入口，不处理全部。",
                zhHant: "只確認時間和入口，不處理全部。",
                ja: "時間と入り口だけを確かめましょう。全部を片づけなくて大丈夫です。",
                ko: "시간과 들어가는 방법만 확인해요. 전부 끝내지 않아도 돼요."
            )
        } else {
            category = .other
            title = lang.pick(
                en: "Prepare this upcoming event for 5 minutes",
                zh: "为即将到来的日程做 5 分钟准备",
                zhHant: "為即將到來的日程做 5 分鐘準備",
                ja: "近づいている予定の準備を5分だけ",
                ko: "다가오는 일정 준비 5분만 하기"
            )
            step = lang.pick(
                en: "Pick one useful detail and prepare the entry point so next step is easier.",
                zh: "只确认一个关键细节并选好入口，让下一步更容易开始。",
                zhHant: "只確認一個關鍵細節並選好入口，讓下一步更容易開始。",
                ja: "役に立つ詳細をひとつ選んで入り口を用意し、次の一歩を始めやすくしましょう。",
                ko: "도움이 될 만한 내용 하나를 골라 시작할 곳을 준비하면 다음 단계가 쉬워져요."
            )
        }
        return NextStepProposal(
            title: title,
            step: step,
            timerMinutes: 5,
            stopCondition: lang.pick(
                en: "Stop after confirming one detail.",
                zh: "确认一个细节就停。",
                zhHant: "確認一個細節就停。",
                ja: "詳細をひとつ確かめられたら止めましょう。",
                ko: "내용 하나를 확인했으면 멈춰요."
            ),
            category: category,
            shrinkLevel: .two,
            generatedBy: .localTemplate,
            whyThisStep: lang.pick(
                en: "Upcoming event prep turns the event into one prep action.",
                zh: "日程准备会把日程变成一个准备动作。",
                zhHant: "日程準備會把日程變成一個準備動作。",
                ja: "予定の準備は、その予定をひとつの準備動作に変えます。",
                ko: "일정 준비는 그 일정을 준비 동작 하나로 바꿔 줘요."
            )
        )
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
        let lang = ContentLanguage(language)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let starts = proofs.filter { $0.createdAt >= start }.count
        let mostCommon = mostCommonPreset(in: frictionSignals.filter { $0.createdAt >= start })
        let window = bestWindow(in: samples)
        let message = starts > 0
            ? lang.pick(
                en: "You started \(starts) times this week. Keep using the smallest doorway.",
                zh: "这周你已经开始了 \(starts) 次。下次继续从最小入口开始。",
                zhHant: "這週你已經開始了 \(starts) 次。下次繼續從最小入口開始。",
                ja: "今週は\(starts)回始められました。これからも、いちばん小さな入り口から始めましょう。",
                ko: "이번 주에 \(starts)번 시작했어요. 앞으로도 가장 작은 문으로 시작해 봐요."
            )
            : lang.pick(
                en: "No starts recorded this week. A 3-minute version is enough to begin.",
                zh: "这周还没有记录开始。可以从 3 分钟版本开始。",
                zhHant: "這週還沒有記錄開始。可以從 3 分鐘版本開始。",
                ja: "今週はまだ記録がありません。3分の版から始めれば十分です。",
                ko: "이번 주에는 아직 기록이 없어요. 3분짜리 버전이면 시작하기에 충분해요."
            )
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
