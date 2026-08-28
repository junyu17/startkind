import Foundation

/// The local One Next Step engine.
///
/// Converts messy user input into exactly one concrete, startable action,
/// fully offline using deterministic templates. This is the Free-tier core
/// and the fallback when cloud AI is unavailable or quota-exhausted.
///
/// Design rules (from `docs/AI_BEHAVIOR_SPEC.md`):
/// - Returns one step by default, never a long list.
/// - Step starts with a verb, is doable in 5–15 minutes.
/// - Includes a clear stop condition.
/// - Low-shame, no moralizing.
struct NextStepEngine: Sendable {
    init() {}

    /// Detect the most likely category from raw text (en + zh keywords).
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

    /// Produce one next step. `calibrationMultiplier` adjusts the timer estimate.
    func generate(
        _ input: CaptureInput,
        calibrationMultiplier: Double = 1.0
    ) -> NextStepProposal {
        if Self.isBadDayInput(input.rawText) {
            return Self.badDayProposal(language: input.language, preferred: input.preferredCategory)
        }
        let category = detectCategory(in: input.rawText, preferred: input.preferredCategory)
        let template = Self.template(for: category, language: input.language)
        let baseMinutes = category.defaultEstimateMinutes
        let adjusted = max(5, min(25, Int((Double(baseMinutes) * calibrationMultiplier).rounded())))
        return NextStepProposal(
            title: template.title,
            step: template.step,
            timerMinutes: adjusted,
            stopCondition: template.stop,
            category: category,
            shrinkLevel: .zero,
            generatedBy: .localTemplate,
            whyThisStep: template.why
        )
    }
}

// MARK: - Templates

extension NextStepEngine {
    struct Template {
        let title: String
        let step: String
        let stop: String
        let why: String?
    }

    static func template(for category: TaskCategory, language: String) -> Template {
        let zh = language.lowercased().hasPrefix("zh")
        let fallback: (Template, Template) = (
            Template(title: "Name the smallest part",
                     step: "Say or write the smallest part of this task out loud.",
                     stop: "Stop after you name it.",
                     why: "Naming it makes it startable."),
            Template(title: "说出最小的一步",
                     step: "把这件事最小的一步说出来或写下来。",
                     stop: "说完就停。",
                     why: "说出来，就能开始了。")
        )
        let table: [TaskCategory: (Template, Template)] = [
            .bills: (
                Template(title: "Find the bill",
                         step: "Open your email and search for the bill sender's name.",
                         stop: "Stop when you see one bill in the results, even if you don't pay it yet.",
                         why: "Just locating it makes the next step easier."),
                Template(title: "找到账单",
                         step: "打开邮件，搜索账单发件人的名字。",
                         stop: "看到一封账单就停下来，先不用付款也没关系。",
                         why: "只要找到它，下一步就容易多了。")
            ),
            .email: (
                Template(title: "Spot the important sender",
                         step: "Open your inbox and sort by sender.",
                         stop: "Stop after you identify the one sender that matters most today.",
                         why: "A single focus beats the whole inbox."),
                Template(title: "找到重要的发件人",
                         step: "打开收件箱，按发件人排序。",
                         stop: "找到今天最重要的一个发件人就停。",
                         why: "只看一个，比面对整个收件箱轻松。")
            ),
            .appointments: (
                Template(title: "See the appointment",
                         step: "Open your calendar and find the appointment you've been avoiding.",
                         stop: "Stop when you can see its date and time.",
                         why: "Seeing it clearly reduces the dread."),
                Template(title: "看清那个预约",
                         step: "打开日历，找到你一直在躲的预约。",
                         stop: "看到它的日期和时间就停。",
                         why: "看清楚了，害怕感会小很多。")
            ),
            .returns: (
                Template(title: "Find the return info",
                         step: "Find the return label or the order email.",
                         stop: "Stop when you can see the return address or barcode.",
                         why: "One piece of info moves it forward."),
                Template(title: "找到退货信息",
                         step: "找到退货标签或订单邮件。",
                         stop: "看到退货地址或条码就停。",
                         why: "先拿到一个信息，就能往前走。")
            ),
            .insurance: (
                Template(title: "Find the due date",
                         step: "Open the insurance email and look for the due date.",
                         stop: "Stop there - you don't need to act on it yet.",
                         why: "Knowing the date is a real step."),
                Template(title: "找到截止日期",
                         step: "打开保险邮件，找截止日期。",
                         stop: "看到日期就停，暂时不用做别的。",
                         why: "知道日期，就是实实在在的一步。")
            ),
            .banking: (
                Template(title: "Check the balance",
                         step: "Open your banking app and find your balance.",
                         stop: "Stop when you can see the number.",
                         why: "A clear number lowers the worry."),
                Template(title: "查看余额",
                         step: "打开银行 App,找到余额。",
                         stop: "看到数字就停。",
                         why: "一个清楚的数字，焦虑就少一点。")
            ),
            .taxes: (
                Template(title: "Open the tax folder",
                         step: "Open the folder where your tax documents live.",
                         stop: "Stop when you can see this year's documents.",
                         why: "Just opening it is progress."),
                Template(title: "打开税务文件夹",
                         step: "打开存放税务文件的文件夹。",
                         stop: "看到今年的文件就停。",
                         why: "光是打开它，就已经在推进了。")
            ),
            .household: (
                Template(title: "Pick up five things",
                         step: "Go to one room and pick up five items.",
                         stop: "Stop after five.",
                         why: "Five is small and finishable."),
                Template(title: "捡起五样东西",
                         step: "去一个房间，捡起 5 样东西。",
                         stop: "捡够 5 样就停。",
                         why: "5 样很少，能做完。")
            ),
            .familyAdmin: (
                Template(title: "Read the first section",
                         step: "Open the school or family form you've been avoiding.",
                         stop: "Stop after you read the first section.",
                         why: "Reading is lighter than filling it out."),
                Template(title: "读第一部分",
                         step: "打开你一直拖着的那份学校或家庭表格。",
                         stop: "读完第一部分就停。",
                         why: "只读不填，负担轻得多。")
            ),
            .medical: (
                Template(title: "Find the clinic number",
                         step: "Open your contacts and find the clinic number.",
                         stop: "Stop when you can see it.",
                         why: "Having the number makes calling easier later."),
                Template(title: "找到诊所电话",
                         step: "打开通讯录，找诊所电话。",
                         stop: "看到号码就停。",
                         why: "有号码在手，之后打电话就容易了。")
            ),
            .workAdmin: (
                Template(title: "Read the avoided message",
                         step: "Open the one work message you've been avoiding.",
                         stop: "Stop after you read it.",
                         why: "Reading it shrinks the unknown."),
                Template(title: "读那条消息",
                         step: "打开你一直躲的那条工作消息。",
                         stop: "读完就停。",
                         why: "读一下，未知就变小了。")
            ),
            .school: (
                Template(title: "Read the instructions",
                         step: "Open the assignment and read the instructions.",
                         stop: "Stop after you read them.",
                         why: "Knowing the ask beats guessing."),
                Template(title: "读要求",
                         step: "打开作业，读一遍要求。",
                         stop: "读完就停。",
                         why: "知道要做什么，比瞎猜好。")
            ),
            .cleaning: (
                Template(title: "Clear one surface",
                         step: "Pick one surface and clear it.",
                         stop: "Stop when that one surface is clear.",
                         why: "One done surface is a win."),
                Template(title: "清空一个台面",
                         step: "选一个台面，把它清空。",
                         stop: "清完这一个就停。",
                         why: "清完一个，就是一次胜利。")
            ),
            .errands: (
                Template(title: "Write one errand",
                         step: "Write the one errand that matters most on a note.",
                         stop: "Stop after you write it.",
                         why: "Out of your head, onto paper."),
                Template(title: "写下一件跑腿",
                         step: "把最重要的一件跑腿写在纸上。",
                         stop: "写完就停。",
                         why: "从脑子里挪到纸上，轻松一点。")
            ),
            .other: fallback
        ]
        let entry = table[category] ?? fallback
        return zh ? entry.1 : entry.0
    }

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
            "我开始不了"
        ]
        return phrases.contains { lower.contains($0) }
    }

    static func badDayProposal(language: String, preferred: TaskCategory?) -> NextStepProposal {
        let zh = language.lowercased().hasPrefix("zh")
        let category = preferred ?? .other
        return NextStepProposal(
            title: zh ? "先回到这一分钟" : "Come back to this minute",
            step: zh ? "坐下，把一只手放在手机上，慢慢呼气一次。" : "Sit down, put one hand on your phone, and take one slow breath out.",
            timerMinutes: 5,
            stopCondition: zh ? "呼完这一口气就停。下一步等会儿再说。" : "Stop after that one breath. The next step can wait.",
            category: category,
            shrinkLevel: .two,
            generatedBy: .localTemplate,
            whyThisStep: zh ? "状态很乱时，先把入口降到几乎不用决定。" : "On a bad day, the first step should require almost no decisions."
        )
    }

    static let categoryKeywords: [(TaskCategory, [String])] = [
        (.bills, ["bill", "invoice", "payment", "pay ", "due date", "账单", "付款", "缴费", "发票", "水电"]),
        (.email, ["email", "inbox", "reply", "forward", "邮件", "收件箱", "回复"]),
        (.appointments, ["appointment", "schedule", "dentist", "doctor", "booking", "reserve", "预约", "牙医", "医生", "预订", "挂号"]),
        (.returns, ["return", "refund", "package", "ship back", "退货", "退款", "包裹", "寄件"]),
        (.insurance, ["insurance", "claim", "policy", "deductible", "保险", "理赔", "保单", "免赔"]),
        (.banking, ["bank", "transfer", "balance", "deposit", "银行", "转账", "余额", "存款"]),
        (.taxes, ["tax", "irs", "报税", "税务", "退税"]),
        (.household, ["laundry", "dishes", "trash", "garbage", "家务", "洗衣", "碗", "垃圾", "倒垃圾"]),
        (.familyAdmin, ["school form", "permission slip", "child", "kid", "家长", "学校表", "孩子", "permission"]),
        (.medical, ["prescription", "refill", "symptom", "clinic", "处方", "症状", "诊所", "看病"]),
        (.workAdmin, ["report", "submit", "expense", "timesheet", "报告", "报销", "提交", "工时"]),
        (.school, ["homework", "assignment", "essay", "study", "作业", "论文", "复习"]),
        (.cleaning, ["clean", "wipe", "vacuum", "mop", "清洁", "擦", "扫", "拖"]),
        (.errands, ["grocery", "store", "pickup", "drop off", "跑腿", "买菜", "取件", "寄"])
    ]
}
