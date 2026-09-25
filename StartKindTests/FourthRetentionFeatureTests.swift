import XCTest
@testable import StartKind

@MainActor
final class FourthRetentionFeatureTests: XCTestCase {
    func testEmergencyTinyModeDetectsEnglishAndChinese() {
        let planner = EmergencyTinyModePlanner()
        XCTAssertTrue(planner.detectsTrigger("I am overwhelmed and cannot start"))
        XCTAssertTrue(planner.detectsTrigger("我今天一团乱"))
        let proposal = planner.proposal(language: "en")
        XCTAssertEqual(proposal.timerMinutes, 3)
        XCTAssertEqual(proposal.shrinkLevel, .three)
    }

    func testQuickActionKindMapsTypesAndProposals() {
        XCTAssertEqual(QuickActionKind(shortcutType: "ren.startkind.shortcut.emergencyTiny"), .emergencyTiny)
        XCTAssertEqual(QuickActionKind.emergencyTiny.proposal(language: "en")?.timerMinutes, 3)
        XCTAssertEqual(QuickActionKind(shortcutType: "ren.startkind.shortcut.stuck"), .stuck)
        XCTAssertEqual(QuickActionKind.startFive.shortcutType, "ren.startkind.shortcut.startFive")
        XCTAssertEqual(QuickActionKind.startFive.proposal(language: "en")?.timerMinutes, 5)
        XCTAssertEqual(QuickActionKind.rescueYesterday.proposal(language: "en")?.timerMinutes, 3)
        XCTAssertNil(QuickActionKind.pasteAdmin.proposal(language: "en"))
    }

    func testAppIntentActionStoreConsumesPendingAction() {
        XCTAssertNil(StartKindIntentActionStore.consume())
        StartKindIntentActionStore.save(.startFive)
        XCTAssertEqual(StartKindIntentActionStore.consume(), .startFive)
        XCTAssertNil(StartKindIntentActionStore.consume())
    }

    func testFrictionMemoryPersistsAndReturnsTopPreset() {
        let suite = "friction-memory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FrictionMemoryStore(defaults: defaults)
        store.record(category: .bills, preset: .needDocument)
        store.record(category: .bills, preset: .needDocument)
        store.record(category: .bills, preset: .needLogin)
        XCTAssertEqual(store.topPreset(for: .bills), .needDocument)
        XCTAssertEqual(store.proposal(for: .bills, language: "en")?.category, .bills)
        let reloaded = FrictionMemoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.signals.count, 3)
        XCTAssertEqual(reloaded.topPreset(for: .bills), .needDocument)
    }

    func testStartScriptsDeduplicatePersistAndMakeProposal() {
        let suite = "start-scripts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StartScriptStore(defaults: defaults)
        let first = store.add(title: "Bill doorway", body: "Open the bill page", category: .bills)
        let duplicate = store.add(title: "Bill doorway", body: "Open the bill page", category: .bills)
        XCTAssertEqual(first.id, duplicate.id)
        XCTAssertEqual(store.scripts.count, 1)
        let proposal = store.proposal(from: first, language: "en")
        XCTAssertEqual(proposal.timerMinutes, 5)
        XCTAssertEqual(proposal.generatedBy, .user)
        let reloaded = StartScriptStore(defaults: defaults)
        XCTAssertEqual(reloaded.scripts.first?.title, "Bill doorway")
        reloaded.delete(id: first.id)
        XCTAssertTrue(reloaded.scripts.isEmpty)
    }

    func testCalendarSoftLandingUsesCalendarDaysAndGenericFallback() {
        let planner = CalendarSoftLandingPlanner()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2023, month: 11, day: 14, hour: 23, minute: 55))!
        let sameDayPast = calendar.date(from: DateComponents(year: 2023, month: 11, day: 14, hour: 9))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let sevenDays = calendar.date(byAdding: .day, value: 7, to: now)!
        let eightDays = calendar.date(byAdding: .day, value: 8, to: now)!

        XCTAssertEqual(
            planner.proposal(
                for: CalendarSoftLandingEvent(title: "Dentist appointment", startDate: tomorrow),
                now: now,
                calendar: calendar,
                language: "en"
            )?.category,
            .medical
        )
        XCTAssertEqual(
            planner.proposal(
                for: CalendarSoftLandingEvent(title: "Electric bill due", startDate: tomorrow),
                now: now,
                calendar: calendar,
                language: "en"
            )?.category,
            .bills
        )

        let generic = planner.proposal(
            for: CalendarSoftLandingEvent(title: "Pick up package", startDate: sameDayPast),
            now: now,
            calendar: calendar,
            language: "en"
        )
        XCTAssertEqual(generic?.category, .other)
        XCTAssertEqual(generic?.timerMinutes, 5)
        XCTAssertTrue(generic?.step.contains("entry point") == true)
        XCTAssertNotNil(
            planner.proposal(
                for: CalendarSoftLandingEvent(title: "Random idea", startDate: sevenDays),
                now: now,
                calendar: calendar,
                language: "en"
            )
        )
        XCTAssertNil(
            planner.proposal(
                for: CalendarSoftLandingEvent(title: "Meeting", startDate: eightDays),
                now: now,
                calendar: calendar,
                language: "en"
            )
        )
        XCTAssertNil(
            planner.proposal(
                for: CalendarSoftLandingEvent(title: "  \n", startDate: tomorrow),
                now: now,
                calendar: calendar,
                language: "en"
            )
        )
    }

    func testGentleReviewIsNonShaming() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let proofs = [ProofOfStartEvent(title: "Open bill", category: .bills, createdAt: now)]
        let signals = [
            FrictionMemorySignal(category: .bills, preset: .needLogin, createdAt: now),
            FrictionMemorySignal(category: .bills, preset: .needLogin, createdAt: now)
        ]
        let samples = [
            CalibrationSample(category: .bills, estimatedMinutes: 5, actualSeconds: 180, outcome: .partial, startHour: 9, coStartUsed: false),
            CalibrationSample(category: .email, estimatedMinutes: 5, actualSeconds: 240, outcome: .completed, startHour: 10, coStartUsed: false)
        ]
        let summary = GentleReviewPlanner().summary(proofs: proofs, frictionSignals: signals, samples: samples, now: now, language: "en")
        XCTAssertEqual(summary.startsThisWeek, 1)
        XCTAssertEqual(summary.mostCommonFriction, .needLogin)
        XCTAssertEqual(summary.bestWindow, "morning")
        XCTAssertFalse(summary.message.lowercased().contains("fail"))
        XCTAssertFalse(summary.message.lowercased().contains("streak"))
    }

    func testWidgetNextStepSnapshotPersists() {
        let suite = "widget-next-step-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WidgetNextStepStore(defaults: defaults)
        let proposal = NextStepProposal(title: "Open bill", step: "Open the bill page", timerMinutes: 5, stopCondition: "Stop", category: .bills)
        store.save(proposal: proposal)
        let reloaded = WidgetNextStepStore(defaults: defaults)
        XCTAssertEqual(reloaded.load()?.title, "Open bill")
        XCTAssertEqual(reloaded.load()?.deepLinkString, "startkind://start")
        reloaded.clear()
        XCTAssertNil(reloaded.load())
    }

    func testDayPartPlannerCreatesSingleEveningRescue() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 21))!
        let planner = DayPartPlanner()
        XCTAssertEqual(planner.dayPart(for: evening, calendar: calendar), .evening)
        let proposal = planner.proposal(now: evening, calendar: calendar, activeCapsule: nil, recentSteps: [], language: "en")
        XCTAssertEqual(proposal.timerMinutes, 3)
        XCTAssertEqual(proposal.shrinkLevel, .three)
    }

    func testFrictionForecastTextHintPriority() {
        let planner = FrictionForecastPlanner()
        XCTAssertEqual(planner.forecast(text: "I need the password", category: .banking, memory: [], language: "en")?.preset, .needLogin)
        XCTAssertEqual(planner.forecast(text: "This is too big and I'm overwhelmed", memory: [], language: "en")?.preset, .tooManyTabs)
        XCTAssertEqual(planner.forecast(text: "I don't know where to start, it feels vague", memory: [], language: "en")?.preset, .tooVague)
        XCTAssertEqual(planner.forecast(text: "Waiting for the bank to reply", memory: [], language: "en")?.preset, .needAnotherPerson)
        XCTAssertEqual(planner.forecast(text: "I'm tired and have no energy", memory: [], language: "en")?.preset, .tooManyTabs)
    }

    func testFrictionForecastEarlierHintWinsAndBeatsMemory() {
        let memory = [
            FrictionMemorySignal(category: .bills, preset: .needAnotherPerson, createdAt: .now),
            FrictionMemorySignal(category: .bills, preset: .needAnotherPerson, createdAt: .now)
        ]
        let planner = FrictionForecastPlanner()
        XCTAssertEqual(planner.forecast(text: "I don't know where the password is", category: .bills, memory: memory, language: "en")?.preset, .needLogin)
        XCTAssertEqual(planner.forecast(text: "Tired and don't know where to start", memory: [], language: "en")?.preset, .tooVague)
    }

    func testFrictionForecastMemoryFallbackWhenNoTextHint() {
        let signal = FrictionMemorySignal(category: .email, preset: .needDocument, createdAt: .now)
        let planner = FrictionForecastPlanner()
        let forecast = planner.forecast(text: "The insurance thing from last week", category: .email, memory: [signal], language: "en")
        XCTAssertEqual(forecast?.preset, .needDocument)
        XCTAssertEqual(forecast?.category, .email)
        XCTAssertTrue(forecast?.reason.contains("restarted") ?? false)
        XCTAssertEqual(forecast?.proposal.generatedBy, .localTemplate)
        XCTAssertEqual(planner.forecast(text: "The insurance thing", category: .bills, memory: [signal], language: "en")?.preset, .needDocument)
    }

    func testFrictionForecastEmptyInputWithoutMemoryIsNil() {
        let planner = FrictionForecastPlanner()
        XCTAssertNil(planner.forecast(text: "", memory: [], language: "en"))
        XCTAssertNil(planner.forecast(text: "   ", memory: [], language: "en"))
        XCTAssertNil(planner.forecast(text: "Just a random note", memory: [], language: "en"))
        let signal = FrictionMemorySignal(category: .bills, preset: .needDocument, createdAt: .now)
        XCTAssertEqual(planner.forecast(text: "", memory: [signal], language: "en")?.preset, .needDocument)
    }

    func testFrictionForecastLocalizesCopy() {
        let en = FrictionForecastPlanner().forecast(text: "I can't login", category: .banking, memory: [], language: "en")
        let zh = FrictionForecastPlanner().forecast(text: "我登录不进去", category: .banking, memory: [], language: "zh-Hans")
        XCTAssertEqual(en?.preset, .needLogin)
        XCTAssertEqual(zh?.preset, .needLogin)
        XCTAssertTrue(en?.reason.contains("password") ?? false)
        XCTAssertTrue(zh?.reason.contains("登录") ?? false)
        XCTAssertTrue(zh?.proposal.title.contains("登录") ?? false)
        XCTAssertEqual(zh?.proposal.generatedBy, .localTemplate)
    }
}
