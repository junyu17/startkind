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
        let zh = language.lowercased().hasPrefix("zh")
        let parts = Self.parts(for: proposal.category, zh: zh)
        let timer = min(proposal.timerMinutes, level.targetMinutes)
        switch level {
        case .zero:
            return proposal
        case .one:
            return proposal.mutating(
                title: zh ? "缩小:找到它" : "Smaller: find it",
                step: zh ? "打开\(parts.object)，找到\(parts.target)。看到就停。" : "Open \(parts.object) and find \(parts.target). Stop when you see it.",
                stopCondition: zh ? "看到\(parts.target)就停。" : "Stop when you see \(parts.target).",
                timerMinutes: timer,
                shrinkLevel: .one
            )
        case .two:
            return proposal.mutating(
                title: zh ? "更小:只打开" : "Tiny: just open it",
                step: zh ? "打开\(parts.object)。打开就停。" : "Open \(parts.object). Stop once it's open.",
                stopCondition: zh ? "打开\(parts.object)就停。" : "Stop once \(parts.object) is open.",
                timerMinutes: timer,
                shrinkLevel: .two
            )
        case .three:
            return proposal.mutating(
                title: zh ? "最小:准备一下" : "Friction-only: set up",
                step: zh ? "把\(parts.tool)放到手边。放好就停。" : "Put \(parts.tool) within reach. Stop once it's there.",
                stopCondition: zh ? "\(parts.tool)到手边就停。" : "Stop once \(parts.tool) is within reach.",
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

    static func parts(for category: TaskCategory, zh: Bool) -> Parts {
        let table: [TaskCategory: (Parts, Parts)] = [
            .bills: (Parts(object: "your email", target: "one bill", tool: "your phone"),
                     Parts(object: "邮件", target: "一封账单", tool: "手机")),
            .email: (Parts(object: "your inbox", target: "the sender list", tool: "your phone"),
                     Parts(object: "收件箱", target: "发件人列表", tool: "手机")),
            .appointments: (Parts(object: "your calendar", target: "the appointment", tool: "your phone"),
                            Parts(object: "日历", target: "那个预约", tool: "手机")),
            .returns: (Parts(object: "the order email", target: "the return label", tool: "the package"),
                       Parts(object: "订单邮件", target: "退货标签", tool: "包裹")),
            .insurance: (Parts(object: "the insurance email", target: "the due date", tool: "your phone"),
                         Parts(object: "保险邮件", target: "截止日期", tool: "手机")),
            .banking: (Parts(object: "your banking app", target: "the balance", tool: "your phone"),
                       Parts(object: "银行 App", target: "余额", tool: "手机")),
            .taxes: (Parts(object: "your tax folder", target: "this year's docs", tool: "your laptop"),
                     Parts(object: "税务文件夹", target: "今年的文件", tool: "笔记本")),
            .household: (Parts(object: "one room", target: "five items", tool: "a trash bag"),
                         Parts(object: "一个房间", target: "五样东西", tool: "垃圾袋")),
            .familyAdmin: (Parts(object: "the form", target: "the first section", tool: "a pen"),
                           Parts(object: "表格", target: "第一部分", tool: "笔")),
            .medical: (Parts(object: "your contacts", target: "the clinic number", tool: "your phone"),
                       Parts(object: "通讯录", target: "诊所电话", tool: "手机")),
            .workAdmin: (Parts(object: "the work message", target: "the message", tool: "your phone"),
                         Parts(object: "工作消息", target: "那条消息", tool: "手机")),
            .school: (Parts(object: "the assignment", target: "the instructions", tool: "your laptop"),
                      Parts(object: "作业", target: "要求", tool: "笔记本")),
            .cleaning: (Parts(object: "one surface", target: "a clear surface", tool: "a cloth"),
                        Parts(object: "一个台面", target: "清空的台面", tool: "抹布")),
            .errands: (Parts(object: "a note", target: "one errand", tool: "a pen"),
                       Parts(object: "便签", target: "一件跑腿", tool: "笔")),
            .other: (Parts(object: "the task", target: "the smallest part", tool: "a note"),
                     Parts(object: "这件事", target: "最小的一步", tool: "便签"))
        ]
        let entry = table[category] ?? table[.other]!
        return zh ? entry.1 : entry.0
    }
}
