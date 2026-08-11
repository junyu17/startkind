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
        XCTAssertEqual(QuickActionKind(shortcutType: "ren.startkind.shortcut.stuck"), .stuck)
        XCTAssertEqual(QuickActionKind.startFive.shortcutType, "ren.startkind.shortcut.startFive")
        XCTAssertEqual(QuickActionKind.startFive.proposal(language: "en")?.timerMinutes, 5)
        XCTAssertEqual(QuickActionKind.rescueYesterday.proposal(language: "en")?.timerMinutes, 3)
        XCTAssertNil(QuickActionKind.pasteAdmin.proposal(language: "en"))
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

    func testCalendarSoftLandingAcceptsRelevantUpcomingEventsOnly() {
        let planner = CalendarSoftLandingPlanner()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tomorrow = now.addingTimeInterval(86_400)
        let farFuture = now.addingTimeInterval(9 * 86_400)
        XCTAssertEqual(planner.proposal(for: CalendarSoftLandingEvent(title: "Dentist appointment", startDate: tomorrow), now: now, language: "en")?.category, .medical)
        XCTAssertEqual(planner.proposal(for: CalendarSoftLandingEvent(title: "Electric bill due", startDate: tomorrow), now: now, language: "en")?.category, .bills)
        XCTAssertNil(planner.proposal(for: CalendarSoftLandingEvent(title: "Random idea", startDate: tomorrow), now: now, language: "en"))
        XCTAssertNil(planner.proposal(for: CalendarSoftLandingEvent(title: "Meeting", startDate: farFuture), now: now, language: "en"))
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
}
