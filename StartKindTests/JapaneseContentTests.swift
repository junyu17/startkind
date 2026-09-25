import XCTest
@testable import StartKind

/// Guards the dynamically generated copy against silently falling back to
/// English for a Japanese user.
///
/// Every generator below used to branch on `hasPrefix("zh")` and pick between a
/// Chinese and an English literal, so `ja` received English. Asserting on kana
/// specifically (rather than "any CJK scalar") is what makes these tests
/// meaningful: kanji alone would also pass for Chinese output.
final class JapaneseContentTests: XCTestCase {
    private let ja = "ja"

    /// Hiragana (U+3040–U+309F) or katakana (U+30A0–U+30FF). Neither appears in
    /// Simplified Chinese or English, so this fails on a fallback in either
    /// direction.
    private func containsKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }

    private func assertJapanese(
        _ text: String,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            containsKana(text),
            "\(label) produced non-Japanese text: \(text)",
            file: file,
            line: line
        )
    }

    private func assertJapanese(
        _ proposal: NextStepProposal,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertJapanese(proposal.title, "\(label).title", file: file, line: line)
        assertJapanese(proposal.step, "\(label).step", file: file, line: line)
        assertJapanese(proposal.stopCondition, "\(label).stopCondition", file: file, line: line)
        if let why = proposal.whyThisStep {
            assertJapanese(why, "\(label).whyThisStep", file: file, line: line)
        }
    }

    private func base(_ category: TaskCategory = .bills) -> NextStepProposal {
        NextStepProposal(
            title: "T", step: "S", timerMinutes: 12, stopCondition: "Stop", category: category
        )
    }

    // MARK: - ContentLanguage

    func testContentLanguageMapsJapaneseTags() {
        XCTAssertEqual(ContentLanguage("ja"), .ja)
        XCTAssertEqual(ContentLanguage("ja-JP"), .ja)
        XCTAssertEqual(ContentLanguage("JA"), .ja)
        XCTAssertEqual(ContentLanguage("zh-Hans"), .zhHans)
        XCTAssertEqual(ContentLanguage("en-GB"), .en)
        XCTAssertEqual(ContentLanguage("fr"), .en, "unsupported languages fall back to English")
    }

    /// Negative control. If `containsKana` ever returned true for English, every
    /// other assertion in this file would pass vacuously and guard nothing.
    func testEnglishOutputHasNoKanaSoTheOtherAssertionsAreMeaningful() {
        let english = NextStepEngine.badDayProposal(language: "en", preferred: nil)
        XCTAssertFalse(containsKana(english.title))
        XCTAssertFalse(containsKana(english.step))
        XCTAssertFalse(
            containsKana(TaskShrinker().shrink(base(), to: .one, language: "en").step),
            "the kana check must discriminate, or this file guards nothing"
        )
    }

    // MARK: - Next step engine

    func testBadDayProposalIsJapanese() {
        assertJapanese(
            NextStepEngine.badDayProposal(language: ja, preferred: nil),
            "badDayProposal"
        )
    }

    func testGeneratedNextStepIsJapanese() {
        let engine = NextStepEngine()
        let proposal = engine.generate(
            CaptureInput(
                rawText: "請求書の支払いをずっと先延ばしにしています",
                source: .text,
                preferredCategory: .bills,
                language: ja
            )
        )
        assertJapanese(proposal, "NextStepEngine.generate")
    }

    /// A Japanese capture must reach the category-specific composer, not the
    /// generic "find an official guide" fallback.
    ///
    /// `TaskIntentParser` has no Japanese grammar parser, so a Japanese intent
    /// carries no verb or object. It still has a category, which is all
    /// `japaneseDomainStep` needs. Before this was wired up, every Japanese
    /// input produced the same generic web-search step and the whole of
    /// `japaneseDomainStep` was unreachable.
    func testJapaneseCaptureReachesTheCategoryComposer() {
        let composer = TaskIntentComposer()
        for (category, forbidden) in [
            (TaskCategory.bills, "公式な案内を探す"),
            (TaskCategory.email, "公式な案内を探す"),
            (TaskCategory.appointments, "公式な案内を探す")
        ] {
            let intent = TaskIntentParser().parse(
                text: "請求書の支払いをずっと先延ばしにしています",
                language: ja,
                categoryHint: category
            )
            XCTAssertEqual(
                intent.strategy,
                .domain,
                "a Japanese intent should use the category-driven composer"
            )
            let proposal = composer.compose(intent: intent, category: category)
            XCTAssertFalse(
                proposal.title.contains(forbidden),
                "\(category) fell back to the generic step: \(proposal.title)"
            )
            assertJapanese(proposal, "composed \(category)")
        }
    }

    // MARK: - Shrinking and rescheduling

    func testEveryCategoryAndLevelShrinksIntoJapanese() {
        let shrinker = TaskShrinker()
        for category in TaskCategory.allCases {
            for level in [ShrinkLevel.one, .two, .three] {
                let shrunk = shrinker.shrink(base(category), to: level, language: ja)
                assertJapanese(shrunk.title, "shrink(\(category), \(level)).title")
                assertJapanese(shrunk.step, "shrink(\(category), \(level)).step")
                assertJapanese(shrunk.stopCondition, "shrink(\(category), \(level)).stop")
            }
        }
    }

    func testEveryRescheduleReasonIsJapanese() {
        let rescheduler = Rescheduler()
        for reason in [SkipReason.skipped, .paused, .tooLarge] {
            let result = rescheduler.reschedule(base(), language: ja, reason: reason)
            assertJapanese(result.message, "reschedule(\(reason)).message")
        }
    }

    // MARK: - Templates and admin

    func testMicroTemplatesAreJapanese() {
        for template in MicroTemplateLibrary.templates(language: ja) {
            assertJapanese(template.proposal, "template(\(template.id))")
        }
    }

    func testAdminTaskReaderIsJapanese() {
        let reader = AdminTaskReader()
        let result = reader.parse(
            text: "電気料金の請求書です。金額は 5,400 円、期限は 2026-10-10 です。",
            language: ja
        )
        assertJapanese(result.oneNextStep, "AdminTaskReader.oneNextStep")
        for document in result.requiredDocuments {
            assertJapanese(document, "AdminTaskReader.requiredDocument")
        }
    }

    // MARK: - Retention kits

    func testEveryEnergyLevelIsJapanese() {
        let matcher = EnergyMatcher()
        for energy in EnergyLevel.allCases {
            let result = matcher.apply(base(), energy: energy, language: ja)
            if let why = result.whyThisStep {
                assertJapanese(why, "energy(\(energy)).whyThisStep")
            }
        }
    }

    func testEveryFrictionPresetIsJapanese() {
        let planner = FrictionPresetPlanner()
        for preset in FrictionPreset.allCases {
            assertJapanese(
                planner.proposal(for: preset, category: .other, language: ja),
                "friction(\(preset))"
            )
        }
    }

    func testEmergencyTinyModeIsJapanese() {
        assertJapanese(EmergencyTinyModePlanner().proposal(language: ja), "emergencyTiny")
    }

    func testQuickActionsAreJapanese() {
        for kind in QuickActionKind.allCases {
            guard let proposal = kind.proposal(language: ja) else { continue }
            assertJapanese(proposal, "quickAction(\(kind))")
        }
    }

    func testEveryDayPartIsJapanese() {
        let planner = DayPartPlanner()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24))!
        for hour in [8, 14, 21] {
            let now = calendar.date(byAdding: .hour, value: hour, to: day)!
            let proposal = planner.proposal(
                now: now,
                calendar: calendar,
                activeCapsule: nil,
                recentSteps: [],
                language: ja
            )
            assertJapanese(proposal, "dayPart(hour: \(hour))")
        }
    }

    func testStartLadderIsJapanese() {
        let planner = StartLadderPlanner()
        for minutes in StartLadderPlanner.minutes {
            let proposal = planner.proposal(from: base(), minutes: minutes, language: ja)
            assertJapanese(proposal.step, "startLadder(\(minutes)).step")
            assertJapanese(proposal.stopCondition, "startLadder(\(minutes)).stop")
        }
    }

    func testActionPrepIsJapanese() {
        let planner = ActionPrepPlanner()
        let plan = planner.plan(for: base(.other), language: ja)
        XCTAssertNotNil(plan)
        if let plan {
            assertJapanese(plan.label, "actionPrep.label")
            assertJapanese(plan.instruction, "actionPrep.instruction")
        }
    }

    func testUrgentAdminSignalIsJapanese() {
        let planner = UrgentAdminPlanner()
        let signal = planner.signal(
            in: "This is a final notice, payment is past due.",
            category: .bills,
            language: ja
        )
        XCTAssertNotNil(signal)
        if let signal {
            assertJapanese(signal.title, "urgent.title")
            assertJapanese(signal.detail, "urgent.detail")
            assertJapanese(signal.proposal, "urgent.proposal")
        }
    }

    // MARK: - Japanese input detection

    /// Before these keywords existed, Japanese input matched nothing and every
    /// capture fell through to `.other`, which made the newly translated copy
    /// generic no matter what the person typed.
    func testJapaneseInputResolvesToTheRightCategory() {
        let engine = NextStepEngine()
        let cases: [(String, TaskCategory)] = [
            ("電気の請求書を払わないといけない", .bills),
            ("先生からのメールに返信する", .email),
            ("歯医者の予約を取る", .appointments),
            ("この靴を返品したい", .returns),
            ("保険の書類を出す", .insurance),
            ("銀行の口座を確認する", .banking),
            ("確定申告をやる", .taxes),
            ("子どもの同意書にサインする", .familyAdmin),
            ("処方箋を薬局に持っていく", .medical),
            ("経費の精算を提出する", .workAdmin),
            ("宿題のレポートを書く", .school),
            ("洗濯をする", .household),
            ("買い物に行く", .errands)
        ]
        for (text, expected) in cases {
            let proposal = engine.generate(
                CaptureInput(rawText: text, source: .text, preferredCategory: nil, language: ja)
            )
            XCTAssertEqual(proposal.category, expected, "\(text) should classify as \(expected)")
        }
    }

    func testJapaneseBadDayInputTriggersTheGentlePath() {
        let engine = NextStepEngine()
        for text in ["今日はもう無理", "頭がぐちゃぐちゃで何も手につかない", "始められない"] {
            let proposal = engine.generate(
                CaptureInput(rawText: text, source: .text, preferredCategory: nil, language: ja)
            )
            XCTAssertEqual(proposal.timerMinutes, 5, "\(text) should take the bad-day path")
            assertJapanese(proposal, "badDay(\(text))")
        }
    }

    func testJapaneseEmergencyTriggerIsDetected() {
        let planner = EmergencyTinyModePlanner()
        XCTAssertTrue(planner.detectsTrigger("もう無理、余裕がない"))
        XCTAssertTrue(planner.detectsTrigger("頭がぐちゃぐちゃ"))
        XCTAssertFalse(planner.detectsTrigger("今日は順調です"))
    }

    func testJapaneseAdminTextIsParsed() {
        let reader = AdminTaskReader()
        let result = reader.parse(
            text: "電気料金の請求書です。金額は 5,400円、お支払い期限は 2026年10月10日 までです。",
            language: ja
        )
        XCTAssertEqual(result.artifactType, .bill)
        XCTAssertEqual(result.amount, "5,400円")
        XCTAssertNotNil(result.dueDate, "a Japanese due date should parse")
        if let due = result.dueDate {
            let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: due)
            XCTAssertEqual(parts.year, 2026)
            XCTAssertEqual(parts.month, 10)
            XCTAssertEqual(parts.day, 10)
        }
    }

    func testJapaneseDateWithoutYearUsesTheCurrentYear() {
        let reader = AdminTaskReader()
        let result = reader.parse(text: "お支払い期限は 10月10日 までです。", language: ja)
        XCTAssertNotNil(result.dueDate)
        if let due = result.dueDate {
            let calendar = Calendar(identifier: .gregorian)
            XCTAssertEqual(
                calendar.component(.year, from: due),
                calendar.component(.year, from: Date()),
                "a bare month/day should be read as this year"
            )
        }
    }

    func testJapaneseUrgentCueIsDetected() {
        let planner = UrgentAdminPlanner()
        XCTAssertNotNil(
            planner.signal(in: "【至急】お支払いの督促です。本日まで。", category: nil, language: ja)
        )
    }

    /// Adding Japanese must not pull Chinese or English input off its category.
    func testAddingJapaneseDidNotDisturbTheOtherLanguages() {
        let engine = NextStepEngine()
        let unchanged: [(String, String, TaskCategory)] = [
            ("zh-Hans", "我要交账单", .bills),
            ("zh-Hans", "回复邮件", .email),
            ("en", "pay the electricity bill", .bills),
            ("en", "reply to the school email", .email)
        ]
        for (language, text, expected) in unchanged {
            let proposal = engine.generate(
                CaptureInput(rawText: text, source: .text, preferredCategory: nil, language: language)
            )
            XCTAssertEqual(proposal.category, expected, "\(language) \"\(text)\" regressed")
        }
    }

    // MARK: - Speech and OCR locales

    @MainActor
    func testSpeechLocaleForJapanese() {
        XCTAssertEqual(
            SpeechService.normalizedLocaleIdentifier(for: Locale(identifier: "ja")),
            "ja-JP"
        )
    }

    func testOCRLanguagesForJapanese() {
        XCTAssertEqual(
            VisionAdminQuickReaderOCRService.recognitionLanguages(for: "ja"),
            ["ja-JP", "en-US"]
        )
    }
}
