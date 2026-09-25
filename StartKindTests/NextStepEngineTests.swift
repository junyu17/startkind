import XCTest
@testable import StartKind

final class NextStepEngineTests: XCTestCase {
    let engine = NextStepEngine()

    func testDetectsBillsByKeyword() {
        XCTAssertEqual(engine.detectCategory(in: "pay the electric bill", preferred: nil), .bills)
        XCTAssertEqual(engine.detectCategory(in: "缴费", preferred: nil), .bills)
    }

    func testDetectsBanking() {
        XCTAssertEqual(engine.detectCategory(in: "transfer money to bank", preferred: nil), .banking)
    }

    func testDetectsReturns() {
        XCTAssertEqual(engine.detectCategory(in: "I need to return this package", preferred: nil), .returns)
    }

    func testPreferredCategoryOverridesDetection() {
        XCTAssertEqual(engine.detectCategory(in: "blah blah", preferred: .medical), .medical)
    }

    func testFallbackIsOther() {
        XCTAssertEqual(engine.detectCategory(in: "xyz qwerty", preferred: nil), .other)
    }

    func testEnglishUnknownIntentKeepsTaskSpecificContextWithoutSecondInput() {
        let proposal = engine.generate(
            CaptureInput(rawText: "I need to sort out a complicated personal project", source: .text, preferredCategory: nil, language: "en")
        )
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertEqual(proposal.category, .other)
        XCTAssertEqual(proposal.timerMinutes, 5)
        XCTAssertTrue(combined.contains("complicated personal project"))
        XCTAssertTrue(combined.contains("sort out"))
        XCTAssertFalse(combined.contains("open where this task lives"))
        XCTAssertTrue(proposal.stopCondition.hasPrefix("Stop when "))
        XCTAssertFalse(combined.contains("say or write"))
    }

    func testChineseUnknownIntentKeepsTaskSpecificContextWithoutSecondInput() {
        let proposal = engine.generate(
            CaptureInput(rawText: "这件事情很复杂", source: .text, preferredCategory: .other, language: "zh-Hans")
        )
        let combined = proposal.title + proposal.step + proposal.stopCondition

        XCTAssertEqual(proposal.category, .other)
        XCTAssertEqual(proposal.timerMinutes, 5)
        XCTAssertTrue(combined.contains("事情很复杂"))
        XCTAssertTrue(combined.contains("这件事情很复杂"))
        XCTAssertTrue(proposal.stopCondition.contains("停"))
        XCTAssertFalse(combined.contains("说出或写下"))
        XCTAssertFalse(combined.contains("说或写"))
    }

    func testRepairIntentKeepsEnglishObjectAndCreatesSafeStartableStep() {
        let proposal = engine.generate(
            CaptureInput(rawText: "fix the fan", source: .text, preferredCategory: nil, language: "en")
        )
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertTrue(combined.contains("fan"))
        XCTAssertFalse(combined.contains("open the app"))
        XCTAssertFalse(combined.contains("message"))
        XCTAssertFalse(combined.contains("document"))
        XCTAssertTrue((5...15).contains(proposal.timerMinutes))
        XCTAssertTrue(proposal.stopCondition.lowercased().contains("stop"))
        XCTAssertTrue(proposal.stopCondition.lowercased().contains("visible"))
        XCTAssertFalse(combined.contains("in front of you"))
        XCTAssertFalse(combined.contains("wiring"))
    }

    func testPaymentRepairIntentKeepsBillsTemplate() {
        let proposal = engine.generate(
            CaptureInput(rawText: "fix my payment issue", source: .text, preferredCategory: nil, language: "en")
        )
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertEqual(proposal.category, .bills)
        XCTAssertEqual(proposal.title, "Find the bill")
        XCTAssertTrue(proposal.step.contains("email"))
        XCTAssertFalse(combined.contains("inspect"))
        XCTAssertFalse(combined.contains("visible symptom"))
        XCTAssertFalse(combined.contains("take it apart"))
    }

    func testRepairIntentKeepsAnotherEnglishObject() {
        let proposal = engine.generate(
            CaptureInput(rawText: "repair my lamp", source: .text, preferredCategory: nil, language: "en")
        )

        XCTAssertTrue("\(proposal.title) \(proposal.step)".lowercased().contains("lamp"))
        XCTAssertTrue((5...15).contains(proposal.timerMinutes))
        XCTAssertFalse(proposal.step.lowercased().contains("open the app"))
    }

    func testRepairIntentSupportsSimplifiedChineseObject() {
        let proposal = engine.generate(
            CaptureInput(rawText: "修理我的台灯", source: .text, preferredCategory: nil, language: "zh-Hans")
        )

        XCTAssertTrue((proposal.title + proposal.step).contains("台灯"))
        XCTAssertTrue((5...15).contains(proposal.timerMinutes))
        XCTAssertTrue(proposal.stopCondition.contains("停"))
        XCTAssertFalse(proposal.step.contains("App、消息或文件"))
    }

    func testRepairIntentSupportsChineseObjectBeforeRepairVerb() {
        let proposal = engine.generate(
            CaptureInput(rawText: "把风扇修好", source: .text, preferredCategory: nil, language: "zh-Hans")
        )

        XCTAssertTrue((proposal.title + proposal.step).contains("风扇"))
        XCTAssertTrue((5...15).contains(proposal.timerMinutes))
        XCTAssertTrue(proposal.stopCondition.contains("停"))
    }

    func testGenerateUsesCalibrationMultiplier() {
        let input = CaptureInput(rawText: "pay bill", source: .text, preferredCategory: nil, language: "en")
        let base = engine.generate(input, calibrationMultiplier: 1.0)
        let scaled = engine.generate(input, calibrationMultiplier: 1.5)
        XCTAssertGreaterThanOrEqual(scaled.timerMinutes, base.timerMinutes)
    }

    func testGenerateClampsTimerTo5And25() {
        let input = CaptureInput(rawText: "pay bill", source: .text, preferredCategory: nil, language: "en")
        let big = engine.generate(input, calibrationMultiplier: 3.0)
        XCTAssertLessThanOrEqual(big.timerMinutes, 25)
        let tiny = engine.generate(input, calibrationMultiplier: 0.1)
        XCTAssertGreaterThanOrEqual(tiny.timerMinutes, 5)
    }

    func testBadDayModeProducesTinyRestartStep() {
        let p = engine.generate(CaptureInput(rawText: "I'm overwhelmed and I can't start", source: .text, preferredCategory: nil, language: "en"))
        XCTAssertEqual(p.category, .other)
        XCTAssertEqual(p.shrinkLevel, .two)
        XCTAssertEqual(p.timerMinutes, 5)
        XCTAssertTrue(p.step.lowercased().contains("breath"))
        XCTAssertFalse((p.whyThisStep ?? "").isEmpty)
    }

    func testBadDayModeSupportsChineseInput() {
        let p = engine.generate(CaptureInput(rawText: "我今天一团乱", source: .text, preferredCategory: .bills, language: "zh-Hans"))
        XCTAssertEqual(p.category, .bills)
        XCTAssertEqual(p.shrinkLevel, .two)
        XCTAssertEqual(p.timerMinutes, 5)
        XCTAssertTrue(p.step.contains("呼气"))
    }

    func testEveryCategoryProducesValidStep() {
        for category in TaskCategory.allCases {
            let p = engine.generate(CaptureInput(rawText: category.rawValue, source: .text, preferredCategory: category, language: "en"))
            XCTAssertEqual(p.category, category)
            XCTAssertFalse(p.title.isEmpty, "no title for \(category)")
            XCTAssertFalse(p.step.isEmpty, "no step for \(category)")
            XCTAssertFalse(p.stopCondition.isEmpty, "no stop for \(category)")
            XCTAssertTrue((5...15).contains(p.timerMinutes), "timer \(p.timerMinutes) for \(category)")
        }
    }

    func testGeneratedByIsLocalTemplate() {
        let p = engine.generate(CaptureInput(rawText: "bill", source: .text, preferredCategory: nil, language: "en"))
        XCTAssertEqual(p.generatedBy, .localTemplate)
    }

    func testParserExtractsEnglishActionObjectAndContext() {
        let intent = TaskIntentParser().parse(
            text: "I need to email my landlord about the leak",
            language: "en",
            categoryHint: .email
        )

        XCTAssertEqual(intent.actionPhrase, "email my landlord about the leak")
        XCTAssertEqual(intent.verb, "email")
        XCTAssertEqual(intent.object, "landlord")
        XCTAssertEqual(intent.context, "about the leak")
        XCTAssertEqual(intent.strategy, .domain)
        XCTAssertTrue(intent.hasConfidentAnchor)
    }

    func testParserExtractsChineseActionAndObject() {
        let intent = TaskIntentParser().parse(
            text: "把我的风扇修好",
            language: "zh-Hans",
            categoryHint: .other
        )

        XCTAssertEqual(intent.verb, "修")
        XCTAssertEqual(intent.object, "风扇")
        XCTAssertEqual(intent.strategy, .repair)
        XCTAssertTrue(intent.hasConfidentAnchor)
    }

    func testRepresentativeEnglishIntentsKeepObjectAndProduceOneFreshStep() {
        let examples = [
            ("paint the wall", "wall"),
            ("buy a new phone", "phone"),
            ("sell my laptop", "laptop"),
            ("feed the dog", "dog"),
            ("mail the package", "package"),
            ("fix the fan", "fan"),
            ("polish the telescope", "telescope")
        ]

        for (task, object) in examples {
            let proposal = engine.generate(
                CaptureInput(rawText: task, source: .text, preferredCategory: nil, language: "en")
            )
            let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

            XCTAssertTrue(combined.contains(object), "Expected \(task) to preserve \(object)")
            XCTAssertTrue(combined.contains(task.split(separator: " ").first.map(String.init) ?? ""), "Expected action verb for \(task)")
            XCTAssertTrue((5...15).contains(proposal.timerMinutes), "Unexpected timer for \(task)")
            XCTAssertFalse(proposal.stopCondition.isEmpty)
            XCTAssertFalse(combined.contains("shame"))
            XCTAssertNil(NextStepQualityGate.rejectionReason(for: proposal, intent: TaskIntentParser().parse(text: task, language: "en")))
        }
    }

    func testRepresentativeChineseIntentsKeepObjectAndProduceOneFreshStep() {
        let examples = [
            ("刷墙", "墙"),
            ("买一部新手机", "新手机"),
            ("卖掉我的笔记本电脑", "笔记本电脑"),
            ("给狗喂饭", "狗"),
            ("把包裹寄出去", "包裹"),
            ("修理风扇", "风扇"),
            ("给望远镜抛光", "望远镜")
        ]

        for (task, object) in examples {
            let proposal = engine.generate(
                CaptureInput(rawText: task, source: .text, preferredCategory: nil, language: "zh-Hans")
            )
            let combined = proposal.title + proposal.step + proposal.stopCondition

            XCTAssertTrue(combined.contains(object), "Expected \(task) to preserve \(object)")
            XCTAssertTrue((5...15).contains(proposal.timerMinutes), "Unexpected timer for \(task)")
            XCTAssertFalse(proposal.stopCondition.isEmpty)
            XCTAssertNil(NextStepQualityGate.rejectionReason(for: proposal, intent: TaskIntentParser().parse(text: task, language: "zh-Hans")))
        }
    }

    func testMailingPackageIsNotClassifiedOrComposedAsReturn() {
        let input = CaptureInput(rawText: "mail the package", source: .text, preferredCategory: nil, language: "en")
        let proposal = engine.generate(input)
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertEqual(proposal.category, .errands)
        XCTAssertFalse(combined.contains("return"))
        XCTAssertTrue(combined.contains("mailing") || combined.contains("label"))

        let selectedReturn = engine.generate(
            CaptureInput(rawText: "mail the package", source: .text, preferredCategory: .returns, language: "en")
        )
        XCTAssertEqual(selectedReturn.category, .returns)
        XCTAssertFalse("\(selectedReturn.title) \(selectedReturn.step)".lowercased().contains("return"))
    }

    func testUnknownVerbProducesExplicitGuideSearchFirstAction() {
        let task = "calibrate the telescope"
        let proposal = engine.generate(CaptureInput(rawText: task, source: .text, preferredCategory: nil, language: "en"))
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertTrue(combined.contains("calibrate"))
        XCTAssertTrue(combined.contains("telescope"))
        XCTAssertTrue(combined.contains("browser"))
        XCTAssertTrue(combined.contains("search"))
        XCTAssertTrue(combined.contains("official guide"))
        XCTAssertTrue(combined.contains("relevant result"))
        XCTAssertTrue(proposal.stopCondition.lowercased().contains("first instruction"))
        XCTAssertTrue(proposal.stopCondition.lowercased().contains("visible"))
        XCTAssertTrue((5...15).contains(proposal.timerMinutes))
    }

    func testUnknownChineseVerbProducesExplicitGuideSearchAndVisibleStop() {
        let task = "校准望远镜"
        let proposal = engine.generate(CaptureInput(rawText: task, source: .text, preferredCategory: nil, language: "zh-Hans"))
        let combined = proposal.title + proposal.step + proposal.stopCondition

        XCTAssertTrue(combined.contains("校准"))
        XCTAssertTrue(combined.contains("望远镜"))
        XCTAssertTrue(combined.contains("浏览器"))
        XCTAssertTrue(combined.contains("搜索"))
        XCTAssertTrue(combined.contains("官方指南"))
        XCTAssertTrue(combined.contains("相关结果"))
        XCTAssertTrue(proposal.stopCondition.contains("第一条说明"))
        XCTAssertTrue(proposal.stopCondition.contains("停"))
        XCTAssertTrue((5...15).contains(proposal.timerMinutes))
    }

    func testReadIntentUsesDirectPageActionInsteadOfResearchTemplate() {
        let proposal = engine.generate(CaptureInput(rawText: "read the book", source: .text, preferredCategory: nil, language: "en"))
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertTrue(combined.contains("book"))
        XCTAssertTrue(proposal.step.lowercased().contains("first page"))
        XCTAssertTrue(proposal.step.lowercased().contains("read one page"))
        XCTAssertEqual(proposal.stopCondition, "Stop after one page.")
        XCTAssertFalse(combined.contains("browser"))
        XCTAssertFalse(combined.contains("official guide"))
    }

    func testOpenIntentUsesDirectVisibleContentsActionInsteadOfCategoryTemplate() {
        let proposal = engine.generate(CaptureInput(rawText: "open the storage box", source: .text, preferredCategory: nil, language: "en"))
        let combined = "\(proposal.title) \(proposal.step) \(proposal.stopCondition)".lowercased()

        XCTAssertTrue(combined.contains("storage box"))
        XCTAssertTrue(proposal.step.lowercased().contains("open"))
        XCTAssertTrue(proposal.step.lowercased().contains("contents are visible"))
        XCTAssertTrue(proposal.stopCondition.lowercased().contains("stop once"))
        XCTAssertFalse(combined.contains("browser"))
        XCTAssertFalse(combined.contains("official guide"))
    }

    func testQualityGateRejectsInvalidCloudResponses() {
        let intent = TaskIntentParser().parse(text: "buy a new phone", language: "en")
        let valid = NextStepProposal(
            title: "Find one phone option",
            step: "Search one trusted store for a new phone and save one option without buying it.",
            timerMinutes: 10,
            stopCondition: "Stop after one option is saved.",
            category: .other,
            generatedBy: .cloudAI
        )
        XCTAssertTrue(NextStepQualityGate.accepts(valid, for: intent))

        let empty = NextStepProposal(title: "", step: "A step", timerMinutes: 10, stopCondition: "Stop", category: .other, generatedBy: .cloudAI)
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: empty, intent: intent), .emptyTitle)

        let outOfRange = NextStepProposal(title: "Find phone", step: "Search for a phone", timerMinutes: 25, stopCondition: "Stop", category: .other, generatedBy: .cloudAI)
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: outOfRange, intent: intent), .timerOutOfRange)

        let list = NextStepProposal(title: "Find phone", step: "1. Search a store\n2. Compare options", timerMinutes: 10, stopCondition: "Stop", category: .other, generatedBy: .cloudAI)
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: list, intent: intent), .listLike)

        let oldFallback = NextStepProposal(title: "Open where this task lives", step: "Open the app, message, document, or physical item connected to this task.", timerMinutes: 5, stopCondition: "Stop when it is open.", category: .other, generatedBy: .cloudAI)
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: oldFallback, intent: intent), .legacyGenericFallback)

        let vagueEnglish = NextStepProposal(title: "Start", step: "Take one small, reversible action toward the task.", timerMinutes: 5, stopCondition: "Stop after that action.", category: .other, generatedBy: .cloudAI)
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: vagueEnglish, intent: intent), .vagueNonAction)

        let vagueChinese = NextStepProposal(title: "开始", step: "围绕这件事做一个小的、可撤回的动作。", timerMinutes: 5, stopCondition: "完成后就停。", category: .other, generatedBy: .cloudAI)
        let chineseIntent = TaskIntentParser().parse(text: "这件事", language: "zh-Hans")
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: vagueChinese, intent: chineseIntent), .vagueNonAction)

        let missingAnchor = NextStepProposal(title: "Check the item", step: "Open the shopping screen.", timerMinutes: 10, stopCondition: "Stop when it is open.", category: .other, generatedBy: .cloudAI)
        XCTAssertEqual(NextStepQualityGate.rejectionReason(for: missingAnchor, intent: intent), .missingTaskAnchor)
    }

    func testQualityGateDoesNotRequireWeakLanguageOrFunctionWordAnchors() {
        let functionWordIntent = TaskIntentParser().parse(text: "I need to do it", language: "en")
        let proposal = NextStepProposal(title: "Open the task context", step: "Open the task context and wait until it is visible.", timerMinutes: 5, stopCondition: "Stop when it is visible.", category: .other, generatedBy: .cloudAI)
        XCTAssertTrue(NextStepQualityGate.accepts(proposal, for: functionWordIntent))

        let unsupportedLanguage = TaskIntentParser().parse(text: "acheter le téléphone", language: "fr")
        XCTAssertFalse(unsupportedLanguage.hasConfidentAnchor)
        XCTAssertTrue(NextStepQualityGate.accepts(proposal, for: unsupportedLanguage))
    }

    func testCloudParserAppliesTheQualityGateBeforeAcceptingAResponse() {
        let input = CaptureInput(rawText: "buy a new phone", source: .text, preferredCategory: nil, language: "en")
        let json: [String: Any] = [
            "title": "Find one phone option",
            "step": "Search one trusted store for a new phone and save one option.",
            "timer_minutes": 10,
            "stop_condition": "Stop after one option is saved.",
            "category": "other",
            "shrink_level": 0
        ]
        XCTAssertNotNil(CloudAIClient.parseNextStep(json, input: input))

        var badTimer = json
        badTimer["timer_minutes"] = 25
        XCTAssertNil(CloudAIClient.parseNextStep(badTimer, input: input))

        var badAnchor = json
        badAnchor["step"] = "Open the shopping screen and look around."
        XCTAssertNil(CloudAIClient.parseNextStep(badAnchor, input: input))
    }

    func testCloudParserPreservesSelectedCategoryOverCloudAndInference() {
        let input = CaptureInput(rawText: "buy a new phone", source: .text, preferredCategory: .returns, language: "en")
        let json: [String: Any] = [
            "title": "Find one phone option",
            "step": "Search one trusted store for a new phone and save one option.",
            "timer_minutes": 10,
            "stop_condition": "Stop after one option is saved.",
            "category": "banking",
            "shrink_level": 0
        ]

        XCTAssertEqual(CloudAIClient.parseNextStep(json, input: input)?.category, .returns)

        let inferredInput = CaptureInput(rawText: "buy a new phone", source: .text, preferredCategory: nil, language: "en")
        XCTAssertEqual(CloudAIClient.parseNextStep(json, input: inferredInput)?.category, .banking)
    }
}
