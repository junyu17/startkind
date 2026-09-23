import Foundation
#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

#if DEBUG
/// Launch-time support for capturing App Store screenshots from a Debug
/// build. Everything here is inert unless `-SCREENSHOT_MODE` is passed on
/// the command line, and the whole file is compiled out of Release builds,
/// so none of this can ship, unlock Plus, or seed demo content in anything
/// a person could install.
///
/// Distinct from `-UITEST`: UI tests want in-memory storage and a pinned
/// "en" language so assertions are stable. Screenshots want the opposite -
/// real on-disk persistence (so seeded content survives the several relaunches
/// it takes to visit every screen) and the language StartKind would actually
/// pick up from `-AppleLanguages`.
enum ScreenshotMode {
    enum Screen: String {
        case start, timer, stuck, patterns, admin, settingsPrivacy
    }

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isActive: Bool { arguments.contains("-SCREENSHOT_MODE") }

    /// Which screen this launch should land on, from `-SCREENSHOT_SCREEN <name>`.
    static var screen: Screen? {
        guard isActive,
              let index = arguments.firstIndex(of: "-SCREENSHOT_SCREEN"),
              arguments.indices.contains(index + 1) else { return nil }
        return Screen(rawValue: arguments[index + 1])
    }

    static var forcePlus: Bool { isActive && arguments.contains("-SCREENSHOT_PLUS") }

    /// `LocalizationManager.init()` derives the display language this same
    /// way from `Locale.preferredLanguages`. `AppEnvironment.init()` normally
    /// reads the language back out of the persisted profile instead, which
    /// defaults an unseeded profile to "en" and so ignores `-AppleLanguages`
    /// entirely on a fresh install - exactly the case every screenshot run
    /// starts from after `simctl uninstall`.
    static var systemPreferredLanguage: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? "zh-Hans" : "en"
    }
}

/// Canned, offline, price-free demo content for each screenshot screen.
/// Written directly in each language rather than through `L()`: this text is
/// only ever seen by whoever is capturing the shots, never a real user, so it
/// does not belong in Localizable.strings.
enum ScreenshotDemoContent {
    private static var isChinese: Bool { ScreenshotMode.systemPreferredLanguage == "zh-Hans" }

    /// The step shown on the Start screen, and reused for the Timer screen so
    /// the two shots read as the same moment.
    static var mainStep: NextStepProposal {
        isChinese
            ? NextStepProposal(
                title: "回复学校的邮件",
                step: "打开邮件，只回复老师发来的那一封。",
                timerMinutes: 10,
                stopCondition: "发送之后就可以停。",
                category: .email
            )
            : NextStepProposal(
                title: "Reply to the school email",
                step: "Open Mail and answer just the one from Emma's teacher.",
                timerMinutes: 10,
                stopCondition: "Stop once you've hit send.",
                category: .email
            )
    }

    /// The paused step behind the Recover ("I'm stuck") screen.
    static var stuckStep: NextStepProposal {
        isChinese
            ? NextStepProposal(
                title: "整理那堆信件",
                step: "先清掉厨房台面上的五个信封。",
                timerMinutes: 8,
                stopCondition: "清完五个就可以停，堆没清完也没关系。",
                category: .household
            )
            : NextStepProposal(
                title: "Sort the mail pile",
                step: "Clear five envelopes off the kitchen counter.",
                timerMinutes: 8,
                stopCondition: "Stop after five, even if the pile isn't gone.",
                category: .household
            )
    }

    static var stuckBlocker: BlockerReason { .tooBig }

    /// A small, varied history so Patterns has real snapshots, a real
    /// recommendation, and a non-zero "starts this week" count to show.
    static var historyEntries: [(proposal: NextStepProposal, outcome: TimerOutcome)] {
        if isChinese {
            return [
                (NextStepProposal(title: "预约牙医体检", step: "打电话约最近的空档。", timerMinutes: 8, stopCondition: "约到时间就可以停。", category: .appointments), .completed),
                (NextStepProposal(title: "清空收件箱", step: "把今天的推送邮件都归档。", timerMinutes: 10, stopCondition: "清空后就可以停。", category: .email), .completed),
                (NextStepProposal(title: "还图书馆的书", step: "今晚就放到门口。", timerMinutes: 5, stopCondition: "放到门口就可以停。", category: .errands), .completed),
                (NextStepProposal(title: "收拾明天的书包", step: "检查作业文件夹在不在里面。", timerMinutes: 6, stopCondition: "文件夹在里面就可以停。", category: .school), .completed),
                (NextStepProposal(title: "回复班级群消息", step: "简单回复一句，让话题能收尾。", timerMinutes: 5, stopCondition: "回复完就可以停。", category: .familyAdmin), .partial)
            ]
        }
        return [
            (NextStepProposal(title: "Book the dentist checkup", step: "Call and ask for the next free slot.", timerMinutes: 8, stopCondition: "Stop once you have a date.", category: .appointments), .completed),
            (NextStepProposal(title: "Clear inbox to zero", step: "Archive every newsletter from today.", timerMinutes: 10, stopCondition: "Stop when the list is empty.", category: .email), .completed),
            (NextStepProposal(title: "Return the library book", step: "Put it by the front door tonight.", timerMinutes: 5, stopCondition: "Stop once it's by the door.", category: .errands), .completed),
            (NextStepProposal(title: "Pack tomorrow's school bag", step: "Check the homework folder is inside.", timerMinutes: 6, stopCondition: "Stop once the folder is in.", category: .school), .completed),
            (NextStepProposal(title: "Reply to the class parent group", step: "Send a short reply so the thread can close.", timerMinutes: 5, stopCondition: "Stop once you've replied.", category: .familyAdmin), .partial)
        ]
    }

    /// The text a person would paste into the Admin Task Reader.
    static var adminPastedText: String {
        isChinese
            ? "Emma 班级郊游的同意书周四截止。请签字后放进书包带回学校。有问题请联系学校办公室。"
            : "Emma's class trip permission slip is due Thursday. Please sign and send it back in her backpack. Contact the school office with any questions."
    }

    /// The parsed result the Admin Task Reader would normally get from the
    /// AI backend. No `amount` on purpose - the simulator always renders
    /// currency as US dollars regardless of locale, which would be wrong on
    /// a Simplified Chinese listing.
    static var adminResult: AdminParseResult {
        let dueDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        if isChinese {
            return AdminParseResult(
                artifactType: .school,
                dueDate: dueDate,
                amount: nil,
                contact: "学校办公室",
                linkOrPhone: nil,
                requiredDocuments: ["签好的同意书"],
                oneNextStep: NextStepProposal(
                    title: "签好同意书",
                    step: "签字后放进 Emma 的书包，明天带去学校。",
                    timerMinutes: 5,
                    stopCondition: "签完放进书包就可以停。",
                    category: .school
                ),
                confidence: 0.92,
                missingInfo: []
            )
        }
        return AdminParseResult(
            artifactType: .school,
            dueDate: dueDate,
            amount: nil,
            contact: "School office",
            linkOrPhone: nil,
            requiredDocuments: ["Signed permission slip"],
            oneNextStep: NextStepProposal(
                title: "Sign the permission slip",
                step: "Sign the form and put it in Emma's bag for tomorrow.",
                timerMinutes: 5,
                stopCondition: "Stop once it's signed and packed.",
                category: .school
            ),
            confidence: 0.92,
            missingInfo: []
        )
    }
}

extension AppEnvironment {
    /// Fills a fresh, on-disk store with a small, realistic history so
    /// Patterns and Recover have real content instead of empty states. Runs
    /// once per install: a second launch (the next screen in the same
    /// locale's shot list) sees existing sessions and skips straight past.
    func seedScreenshotDataIfNeeded() {
        guard ScreenshotMode.isActive else { return }
        // The Timer screenshot starts a real Live Activity so the in-app
        // screen renders correctly, but each screen is its own `simctl
        // launch` and Live Activities survive process termination - left
        // alone, it would still be showing in the Dynamic Island for every
        // screen captured after it. `Activity<...>.activities` lists every
        // current activity regardless of which launch started it.
        endDanglingScreenshotLiveActivities()

        guard persistence.recentSessions(days: nil).isEmpty else { return }

        for entry in ScreenshotDemoContent.historyEntries {
            let step = createLocalNextStep(proposal: entry.proposal, sourceText: entry.proposal.step)
            let session = startTimer(step: step, minutes: entry.proposal.timerMinutes)
            finishTimer(session: session, actualSeconds: entry.proposal.timerMinutes * 60, outcome: entry.outcome, step: step)
            if entry.outcome == .completed {
                recordProofOfStart(step: step)
            }
        }

        // Seeded last, and with a non-completed outcome, so it is the one
        // capsule still active for the Recover screen - a completed outcome
        // above would otherwise have cleared it.
        let stuckStepModel = createLocalNextStep(proposal: ScreenshotDemoContent.stuckStep, sourceText: ScreenshotDemoContent.stuckStep.step)
        let stuckSession = startTimer(step: stuckStepModel, minutes: ScreenshotDemoContent.stuckStep.timerMinutes)
        finishTimer(session: stuckSession, actualSeconds: 90, outcome: .paused, step: stuckStepModel, blocker: ScreenshotDemoContent.stuckBlocker)
    }

    /// A fresh timer session for the Timer screenshot itself. Not seeded
    /// alongside history: it needs live `NextStepModel`/`TimerSessionModel`
    /// instances to hand `TimerView`, not just persisted rows.
    func makeScreenshotTimerRoute() -> TimerRoute {
        let step = createLocalNextStep(proposal: ScreenshotDemoContent.mainStep, sourceText: ScreenshotDemoContent.mainStep.step)
        let session = startTimer(step: step, minutes: ScreenshotDemoContent.mainStep.timerMinutes)
        return TimerRoute(session: session, step: step)
    }

    private func endDanglingScreenshotLiveActivities() {
#if canImport(ActivityKit)
        Task {
            for activity in Activity<StartKindTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
#endif
    }
}
#endif
