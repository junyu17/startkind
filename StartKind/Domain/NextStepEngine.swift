import Foundation

/// The local One Next Step engine.
///
/// Intent is parsed before category metadata is consulted. Categories remain
/// useful for calibration and downstream analytics, but they never determine
/// the action copy by themselves.
struct NextStepEngine: Sendable {
    private let parser: TaskIntentParser
    private let composer: TaskIntentComposer

    init(parser: TaskIntentParser = TaskIntentParser(), composer: TaskIntentComposer = TaskIntentComposer()) {
        self.parser = parser
        self.composer = composer
    }

    /// Detect the most likely category from raw text (en + zh keywords).
    /// The preferred category is UI metadata; it is retained for calibration
    /// and display, while the composer still reads the task intent.
    func detectCategory(in text: String, preferred: TaskCategory?) -> TaskCategory {
        if let preferred { return preferred }
        let lower = text.lowercased()
        for (category, keywords) in Self.categoryKeywords {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return .other
    }

    /// Produce one fresh next step. `calibrationMultiplier` adjusts only the
    /// estimate; it does not change the task semantics.
    func generate(
        _ input: CaptureInput,
        calibrationMultiplier: Double = 1.0
    ) -> NextStepProposal {
        if Self.isBadDayInput(input.rawText) {
            return Self.badDayProposal(language: input.language, preferred: input.preferredCategory)
        }

        let semanticCategory = detectCategory(in: input.rawText, preferred: nil)
        let outputCategory = detectCategory(in: input.rawText, preferred: input.preferredCategory)
        let intent = parser.parse(
            text: input.rawText,
            language: input.language,
            categoryHint: semanticCategory
        )
        return composer.compose(
            intent: intent,
            category: outputCategory,
            calibrationMultiplier: calibrationMultiplier
        )
    }

    static func badDayProposal(language: String, preferred: TaskCategory?) -> NextStepProposal {
        let lang = ContentLanguage(language)
        let category = preferred ?? .other
        return NextStepProposal(
            title: lang.pick(
                en: "Come back to this minute",
                zh: "先回到这一分钟",
                ja: "まず、この一分に戻りましょう"
            ),
            step: lang.pick(
                en: "Sit down, put one hand on your phone, and take one slow breath out.",
                zh: "坐下，把一只手放在手机上，慢慢呼气一次。",
                ja: "座って、スマホに片手を置いて、ゆっくり息を吐きましょう。"
            ),
            timerMinutes: 5,
            stopCondition: lang.pick(
                en: "Stop after that one breath. The next step can wait.",
                zh: "呼完这一口气就停。下一步等会儿再说。",
                ja: "その一息で止めて大丈夫です。次の一歩は、あとで。"
            ),
            category: category,
            shrinkLevel: .two,
            generatedBy: .localTemplate,
            whyThisStep: lang.pick(
                en: "On a bad day, the first step should require almost no decisions.",
                zh: "状态很乱时，先把入口降到几乎不用决定。",
                ja: "調子が整わない日は、最初の一歩に決めることがほとんど要らないほうが動きやすくなります。"
            )
        )
    }
}

private extension NextStepEngine {
    static func isBadDayInput(_ text: String) -> Bool {
        let lower = text.lowercased()
        let phrases = [
            "i am a mess today",
            "i'm a mess today",
            "im a mess today",
            "i am overwhelmed",
            "i'm overwhelmed",
            "im overwhelmed",
            "i can't start",
            "i cant start",
            "can't start",
            "cant start",
            "too overwhelmed",
            "一团乱",
            "我今天一团乱",
            "太乱了",
            "开始不了",
            "我开始不了",
            // Japanese. Written out in the forms people actually type, since
            // there is no stemming here: plain and polite, kana and kanji.
            "ぐちゃぐちゃ",
            "ごちゃごちゃ",
            "いっぱいいっぱい",
            "手につかない",
            "何も手につかない",
            "始められない",
            "はじめられない",
            "動けない",
            "うごけない",
            "もう無理",
            "もうむり",
            "余裕がない",
            "しんどい",
            "疲れた",
            "つかれた"
        ]
        return phrases.contains { lower.contains($0) }
    }

    /// These are intentionally metadata signals, not generation templates.
    /// In particular, a package is not a return without an explicit return or
    /// refund signal; mailing is treated as an errand instead.
    static let categoryKeywords: [(TaskCategory, [String])] = [
        (.returns, ["return", "refund", "ship back", "return label", "退货", "退款", "寄回", "退回", "返品", "返金", "送り返", "返送"]),
        (.email, ["email", "inbox", "reply", "forward", "邮件", "收件箱", "回复", "メール", "受信トレイ", "返信", "転送"]),
        (.appointments, ["appointment", "schedule", "dentist", "doctor", "booking", "reserve", "预约", "牙医", "医生", "预订", "挂号", "予約", "歯医者", "歯科", "医者", "診察", "面談"]),
        (.bills, ["bill", "invoice", "payment", "pay", "due date", "账单", "付款", "缴费", "发票", "水电", "請求書", "請求", "支払い", "支払", "振込", "料金", "光熱費", "領収書"]),
        (.insurance, ["insurance", "claim", "policy", "deductible", "保险", "理赔", "保单", "免赔", "保険", "保険金", "証券番号", "給付金"]),
        (.banking, ["bank", "transfer", "balance", "deposit", "银行", "转账", "余额", "存款", "銀行", "口座", "残高", "入金", "送金"]),
        (.taxes, ["tax", "irs", "报税", "税务", "退税", "確定申告", "税金", "納税", "源泉徴収"]),
        (.familyAdmin, ["school form", "permission slip", "child", "kid", "家长", "学校表", "孩子", "permission", "同意書", "保護者", "子ども", "子供", "連絡帳"]),
        (.medical, ["prescription", "refill", "symptom", "clinic", "处方", "症状", "诊所", "看病", "処方箋", "処方", "薬局", "クリニック", "通院"]),
        (.workAdmin, ["report", "submit", "expense", "timesheet", "报告", "报销", "提交", "工时", "報告書", "経費", "精算", "勤怠", "提出"]),
        (.school, ["homework", "assignment", "essay", "study", "作业", "论文", "复习", "宿題", "課題", "レポート", "予習", "復習"]),
        (.cleaning, ["clean", "wipe", "vacuum", "mop", "清洁", "擦", "扫", "拖", "掃除", "拭く", "掃除機", "モップ"]),
        (.household, ["laundry", "dishes", "trash", "garbage", "家务", "洗衣", "碗", "垃圾", "倒垃圾", "洗濯", "食器", "皿洗い", "ゴミ", "ごみ", "家事", "片づけ", "片付け"]),
        (.errands, ["grocery", "store", "pickup", "drop off", "mail", "post", "ship", "邮寄", "寄出", "寄件", "跑腿", "买菜", "取件", "寄", "買い物", "スーパー", "受け取り", "発送", "郵送", "郵便局", "用事"])
    ]
}
