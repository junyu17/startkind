import Foundation

/// Shrinks a step into smaller, lower-friction versions.
///
/// Implements the four shrink levels from `docs/AI_BEHAVIOR_SPEC.md`:
/// - Level 0: original useful step (10–15m)
/// - Level 1: smaller (5–10m)
/// - Level 2: tiny (2–5m)
/// - Level 3: friction-only (<2m)
///
/// Uses compact combinatorial templates per category (object / target / tool)
/// so every category is covered without 120 hand-written strings.
struct TaskShrinker: Sendable {
    init() {}

    /// Return a smaller version of `proposal` at `level`.
    /// Only shrinks (level increases); requesting a smaller-or-equal level returns the input unchanged.
    func shrink(_ proposal: NextStepProposal, to level: ShrinkLevel, language: String) -> NextStepProposal {
        guard level > proposal.shrinkLevel else {
            return proposal
        }
        let lang = ContentLanguage(language)
        let parts = Self.parts(for: proposal.category, language: lang)
        let timer = min(proposal.timerMinutes, level.targetMinutes)
        switch level {
        case .zero:
            return proposal
        case .one:
            return proposal.mutating(
                title: lang.pick(
                    en: "Smaller: find it",
                    zh: "缩小：找到它",
                    zhHant: "縮小：找到它",
                    ja: "小さく：見つけるだけ",
                    ko: "더 작게: 찾기만"
                ),
                step: lang.pick(
                    en: "Open \(parts.object) and find \(parts.target). Stop when you see it.",
                    zh: "打开\(parts.object)，找到\(parts.target)。看到就停。",
                    zhHant: "開啟\(parts.object)，找到\(parts.target)。看到就停。",
                    ja: "\(parts.object)を開いて、\(parts.target)を見つけましょう。見つかったら止めて大丈夫です。",
                    ko: "열어 볼 곳: \(parts.object). 찾아볼 것: \(parts.target). 보이면 멈춰도 돼요."
                ),
                stopCondition: lang.pick(
                    en: "Stop when you see \(parts.target).",
                    zh: "看到\(parts.target)就停。",
                    zhHant: "看到\(parts.target)就停。",
                    ja: "\(parts.target)が見つかったら止めましょう。",
                    ko: "찾으면 멈춰요: \(parts.target)."
                ),
                timerMinutes: timer,
                shrinkLevel: .one
            )
        case .two:
            return proposal.mutating(
                title: lang.pick(
                    en: "Tiny: just open it",
                    zh: "更小：只打开",
                    zhHant: "更小：只打開",
                    ja: "もっと小さく：開くだけ",
                    ko: "더 작게: 열기만"
                ),
                step: lang.pick(
                    en: "Open \(parts.object). Stop once it's open.",
                    zh: "打开\(parts.object)。打开就停。",
                    zhHant: "開啟\(parts.object)。開啟就停。",
                    ja: "\(parts.object)を開きましょう。開いたら止めて大丈夫です。",
                    ko: "열어 볼 곳: \(parts.object). 열렸으면 멈춰도 돼요."
                ),
                stopCondition: lang.pick(
                    en: "Stop once \(parts.object) is open.",
                    zh: "打开\(parts.object)就停。",
                    zhHant: "開啟\(parts.object)就停。",
                    ja: "\(parts.object)が開いたら止めましょう。",
                    ko: "열렸으면 멈춰요: \(parts.object)."
                ),
                timerMinutes: timer,
                shrinkLevel: .two
            )
        case .three:
            return proposal.mutating(
                title: lang.pick(
                    en: "Friction-only: set up",
                    zh: "最小：准备一下",
                    zhHant: "最小：準備一下",
                    ja: "最小：準備だけ",
                    ko: "최소: 준비만"
                ),
                step: lang.pick(
                    en: "Put \(parts.tool) within reach. Stop once it's there.",
                    zh: "把\(parts.tool)放到手边。放好就停。",
                    zhHant: "把\(parts.tool)放到手邊。放好就停。",
                    ja: "\(parts.tool)を手の届くところに置きましょう。置けたら止めて大丈夫です。",
                    ko: "손 닿는 곳에 둘 것: \(parts.tool). 뒀으면 멈춰도 돼요."
                ),
                stopCondition: lang.pick(
                    en: "Stop once \(parts.tool) is within reach.",
                    zh: "\(parts.tool)到手边就停。",
                    zhHant: "\(parts.tool)到手邊就停。",
                    ja: "\(parts.tool)が手元にあれば止めましょう。",
                    ko: "손 닿는 곳에 뒀으면 멈춰요: \(parts.tool)."
                ),
                timerMinutes: timer,
                shrinkLevel: .three
            )
        }
    }

    /// The next smaller level after the current one, clamped to `.three`.
    func nextLevel(after level: ShrinkLevel) -> ShrinkLevel {
        switch level {
        case .zero: return .one
        case .one: return .two
        case .two: return .three
        case .three: return .three
        }
    }
}

private extension NextStepProposal {
    func mutating(
        title: String,
        step: String,
        stopCondition: String,
        timerMinutes: Int,
        shrinkLevel: ShrinkLevel
    ) -> NextStepProposal {
        NextStepProposal(
            id: UUID(),
            title: title,
            step: step,
            timerMinutes: timerMinutes,
            stopCondition: stopCondition,
            category: category,
            shrinkLevel: shrinkLevel,
            generatedBy: generatedBy,
            whyThisStep: whyThisStep
        )
    }
}

private extension TaskShrinker {
    struct Parts { let object: String; let target: String; let tool: String }

    /// One row of the template table: the same three slots in each content language.
    struct LocalizedParts {
        let en: Parts
        let zh: Parts
        let zhHant: Parts
        let ja: Parts
        let ko: Parts

        func callAsFunction(_ language: ContentLanguage) -> Parts {
            switch language {
            case .en: return en
            case .zhHans: return zh
            case .zhHant: return zhHant
            case .ja: return ja
            case .ko: return ko
            }
        }
    }

    static func parts(for category: TaskCategory, language: ContentLanguage) -> Parts {
        // Japanese slots are bare noun phrases on purpose: the step templates
        // attach the particle (`\(object)を開いて`), so anything ending in a
        // particle here would produce a double-particle sentence. The Korean
        // templates go further and put the slot after a colon, so no particle
        // has to agree with the final syllable of a noun.
        let fallback = LocalizedParts(
            en: Parts(object: "the task", target: "the smallest part", tool: "a note"),
            zh: Parts(object: "这件事", target: "最小的一步", tool: "便签"),
            zhHant: Parts(object: "這件事", target: "最小的一步", tool: "便籤"),
            ja: Parts(object: "このタスク", target: "いちばん小さい部分", tool: "メモ帳"),
            ko: Parts(object: "이 일", target: "가장 작은 부분", tool: "메모지")
        )
        let table: [TaskCategory: LocalizedParts] = [
            .bills: LocalizedParts(
                en: Parts(object: "your email", target: "one bill", tool: "your phone"),
                zh: Parts(object: "邮件", target: "一封账单", tool: "手机"),
                zhHant: Parts(object: "郵件", target: "一封帳單", tool: "手機"),
                ja: Parts(object: "メール", target: "1通の請求書", tool: "スマホ"),
                ko: Parts(object: "메일", target: "청구서 한 통", tool: "휴대폰")
            ),
            .email: LocalizedParts(
                en: Parts(object: "your inbox", target: "the sender list", tool: "your phone"),
                zh: Parts(object: "收件箱", target: "发件人列表", tool: "手机"),
                zhHant: Parts(object: "收件箱", target: "發件人列表", tool: "手機"),
                ja: Parts(object: "受信トレイ", target: "送信者の一覧", tool: "スマホ"),
                ko: Parts(object: "받은편지함", target: "보낸 사람 목록", tool: "휴대폰")
            ),
            .appointments: LocalizedParts(
                en: Parts(object: "your calendar", target: "the appointment", tool: "your phone"),
                zh: Parts(object: "日历", target: "那个预约", tool: "手机"),
                zhHant: Parts(object: "日曆", target: "那個預約", tool: "手機"),
                ja: Parts(object: "カレンダー", target: "その予約", tool: "スマホ"),
                ko: Parts(object: "캘린더", target: "그 예약", tool: "휴대폰")
            ),
            .returns: LocalizedParts(
                en: Parts(object: "the order email", target: "the return label", tool: "the package"),
                zh: Parts(object: "订单邮件", target: "退货标签", tool: "包裹"),
                zhHant: Parts(object: "訂單郵件", target: "退貨標籤", tool: "包裹"),
                ja: Parts(object: "注文メール", target: "返品ラベル", tool: "荷物"),
                ko: Parts(object: "주문 확인 메일", target: "반품 라벨", tool: "택배 상자")
            ),
            .insurance: LocalizedParts(
                en: Parts(object: "the insurance email", target: "the due date", tool: "your phone"),
                zh: Parts(object: "保险邮件", target: "截止日期", tool: "手机"),
                zhHant: Parts(object: "保險郵件", target: "截止日期", tool: "手機"),
                ja: Parts(object: "保険のメール", target: "支払期限", tool: "スマホ"),
                ko: Parts(object: "보험 메일", target: "납부 기한", tool: "휴대폰")
            ),
            .banking: LocalizedParts(
                en: Parts(object: "your banking app", target: "the balance", tool: "your phone"),
                zh: Parts(object: "银行 App", target: "余额", tool: "手机"),
                zhHant: Parts(object: "銀行 App", target: "餘額", tool: "手機"),
                ja: Parts(object: "銀行アプリ", target: "残高", tool: "スマホ"),
                ko: Parts(object: "은행 앱", target: "잔액", tool: "휴대폰")
            ),
            .taxes: LocalizedParts(
                en: Parts(object: "your tax folder", target: "this year's docs", tool: "your laptop"),
                zh: Parts(object: "税务文件夹", target: "今年的文件", tool: "笔记本"),
                zhHant: Parts(object: "稅務資料夾", target: "今年的檔案", tool: "筆記本"),
                ja: Parts(object: "税金の書類フォルダ", target: "今年の書類", tool: "パソコン"),
                ko: Parts(object: "세금 서류 폴더", target: "올해 서류", tool: "노트북")
            ),
            .household: LocalizedParts(
                en: Parts(object: "one room", target: "five items", tool: "a trash bag"),
                zh: Parts(object: "一个房间", target: "五样东西", tool: "垃圾袋"),
                zhHant: Parts(object: "一個房間", target: "五樣東西", tool: "垃圾袋"),
                ja: Parts(object: "部屋のドア", target: "5つのもの", tool: "ゴミ袋"),
                ko: Parts(object: "방 한 곳", target: "물건 다섯 개", tool: "쓰레기봉투")
            ),
            .familyAdmin: LocalizedParts(
                en: Parts(object: "the form", target: "the first section", tool: "a pen"),
                zh: Parts(object: "表格", target: "第一部分", tool: "笔"),
                zhHant: Parts(object: "表格", target: "第一部分", tool: "筆"),
                ja: Parts(object: "その書類", target: "最初の欄", tool: "ペン"),
                ko: Parts(object: "그 서식", target: "첫 번째 칸", tool: "펜")
            ),
            .medical: LocalizedParts(
                en: Parts(object: "your contacts", target: "the clinic number", tool: "your phone"),
                zh: Parts(object: "通讯录", target: "诊所电话", tool: "手机"),
                zhHant: Parts(object: "通訊錄", target: "診所電話", tool: "手機"),
                ja: Parts(object: "連絡先", target: "クリニックの電話番号", tool: "スマホ"),
                ko: Parts(object: "연락처", target: "병원 전화번호", tool: "휴대폰")
            ),
            .workAdmin: LocalizedParts(
                en: Parts(object: "the work message", target: "the message", tool: "your phone"),
                zh: Parts(object: "工作消息", target: "那条消息", tool: "手机"),
                zhHant: Parts(object: "工作訊息", target: "那條訊息", tool: "手機"),
                ja: Parts(object: "仕事のメッセージ", target: "そのメッセージ", tool: "スマホ"),
                ko: Parts(object: "업무 메시지", target: "그 메시지", tool: "휴대폰")
            ),
            .school: LocalizedParts(
                en: Parts(object: "the assignment", target: "the instructions", tool: "your laptop"),
                zh: Parts(object: "作业", target: "要求", tool: "笔记本"),
                zhHant: Parts(object: "作業", target: "要求", tool: "筆記本"),
                ja: Parts(object: "課題", target: "課題の指示", tool: "パソコン"),
                ko: Parts(object: "과제", target: "과제 안내", tool: "노트북")
            ),
            .cleaning: LocalizedParts(
                en: Parts(object: "one surface", target: "a clear surface", tool: "a cloth"),
                zh: Parts(object: "一个台面", target: "清空的台面", tool: "抹布"),
                zhHant: Parts(object: "一個檯面", target: "清空的檯面", tool: "抹布"),
                ja: Parts(object: "台", target: "片づける場所", tool: "ふきん"),
                ko: Parts(object: "평평한 곳 한 군데", target: "비워 둔 공간", tool: "행주")
            ),
            .errands: LocalizedParts(
                en: Parts(object: "a note", target: "one errand", tool: "a pen"),
                zh: Parts(object: "便签", target: "一件跑腿", tool: "笔"),
                zhHant: Parts(object: "便籤", target: "一件跑腿", tool: "筆"),
                ja: Parts(object: "メモ", target: "ひとつの用事", tool: "ペン"),
                ko: Parts(object: "메모", target: "볼일 하나", tool: "펜")
            ),
            .other: fallback
        ]
        return (table[category] ?? fallback)(language)
    }
}
