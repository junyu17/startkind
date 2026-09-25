import Foundation

/// Abstraction over AI generation. Free uses deterministic local templates;
/// Plus routes through the StartKind backend proxy when configured
/// and authenticated, degrading gracefully to local when offline or unconfigured.
protocol AIClient: Sendable {
    func generateNextStep(
        input: CaptureInput,
        calibrationMultiplier: Double
    ) async throws -> NextStepProposal

    func parseAdmin(text: String, language: String) async throws -> AdminParseResult
}

/// Pure local implementation. Offline, zero cost, fully testable.
struct LocalAIClient: AIClient {
    let engine: NextStepEngine
    let reader: AdminTaskReader

    init(engine: NextStepEngine = NextStepEngine(), reader: AdminTaskReader = AdminTaskReader()) {
        self.engine = engine
        self.reader = reader
    }

    func generateNextStep(
        input: CaptureInput,
        calibrationMultiplier: Double
    ) async throws -> NextStepProposal {
        engine.generate(input, calibrationMultiplier: calibrationMultiplier)
    }

    func parseAdmin(text: String, language: String) async throws -> AdminParseResult {
        reader.parse(text: text, language: language)
    }
}

/// Cloud implementation. Calls the StartKind backend when one is configured;
/// otherwise falls back to the on-device engine so the app stays fully usable
/// offline (per the architecture's graceful-degradation rule).
final class CloudAIClient: AIClient {
    private let fallback = LocalAIClient()
    private let api: StartKindAPI?

    init(api: StartKindAPI? = StartKindAPI()) {
        self.api = api
    }

    func generateNextStep(
        input: CaptureInput,
        calibrationMultiplier: Double
    ) async throws -> NextStepProposal {
        guard let api else {
            return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
        }
        do {
            let data = try await api.nextStep(
                input: input.rawText,
                language: input.language,
                calibrationMultiplier: calibrationMultiplier
            )
            if let json = Self.json(from: data), let proposal = Self.parseNextStep(json, input: input) { return proposal }
            return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
        } catch APIError.limitReached {
            // The daily allowance is a product rule, not a failure: surface it
            // so the paywall can explain it.
            throw UsageError.stepLimitReached
        } catch {
            return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
        }
    }

    func parseAdmin(text: String, language: String) async throws -> AdminParseResult {
        guard let api else {
            return try await fallback.parseAdmin(text: text, language: language)
        }
        do {
            let data = try await api.adminParse(text: text, language: language)
            if let json = Self.json(from: data), let result = Self.parseAdminResult(json) { return result }
            return try await fallback.parseAdmin(text: text, language: language)
        } catch {
            // `plusRequired` means only the cloud parse is Plus-gated, not the
            // feature. Free users still get their documented one-per-day Admin
            // Quick Start from the local reader; the paywall is raised by
            // `canUseAdminQuickStart` once that allowance is spent.
            return try await fallback.parseAdmin(text: text, language: language)
        }
    }

    private static func json(from data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func parseNextStep(_ json: [String: Any], input: CaptureInput) -> NextStepProposal? {
        guard let title = json["title"] as? String,
              let step = json["step"] as? String,
              let stopCondition = json["stop_condition"] as? String,
              let timer = json["timer_minutes"] as? Int else { return nil }
        let inferredCategory = NextStepEngine().detectCategory(in: input.rawText, preferred: nil)
        let category = input.preferredCategory
            ?? (json["category"] as? String).flatMap(TaskCategory.init(rawValue:))
            ?? inferredCategory
        let shrink = (json["shrink_level"] as? Int).flatMap(ShrinkLevel.init(rawValue:)) ?? .zero
        let proposal = NextStepProposal(
            title: title,
            step: step,
            timerMinutes: timer,
            stopCondition: stopCondition,
            category: category,
            shrinkLevel: shrink,
            generatedBy: .cloudAI,
            whyThisStep: json["why_this_step"] as? String
        )
        let intent = TaskIntentParser().parse(
            text: input.rawText,
            language: input.language,
            categoryHint: inferredCategory
        )
        guard NextStepQualityGate.accepts(proposal, for: intent) else { return nil }
        return proposal
    }

    private static func parseAdminResult(_ json: [String: Any]) -> AdminParseResult? {
        let type = (json["artifact_type"] as? String).flatMap(AdminArtifactType.init(rawValue:)) ?? .other
        guard let nextJson = json["one_next_step"] as? [String: Any],
              let title = nextJson["title"] as? String,
              let step = nextJson["step"] as? String,
              let timer = nextJson["timer_minutes"] as? Int,
              let stopCondition = nextJson["stop_condition"] as? String else { return nil }
        // The admin prompt asks for the smallest possible action and its own
        // template shows 0 minutes, so the model routinely returns a duration
        // outside the 5-15 the quality gate enforces. Clamping keeps a good
        // parse instead of silently discarding it and dropping the paid cloud
        // result back to the local regex reader.
        let clampedTimer = min(15, max(5, timer))
        let nextStep = NextStepProposal(
            title: title,
            step: step,
            timerMinutes: clampedTimer,
            stopCondition: stopCondition,
            category: .other,
            shrinkLevel: .one,
            generatedBy: .cloudAI
        )
        guard NextStepQualityGate.accepts(nextStep) else { return nil }
        let dueDate = (json["due_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        return AdminParseResult(
            artifactType: type,
            dueDate: dueDate,
            amount: json["amount"] as? String,
            contact: json["contact"] as? String,
            linkOrPhone: json["link_or_phone"] as? String,
            requiredDocuments: (json["required_documents"] as? [String]) ?? [],
            oneNextStep: nextStep,
            confidence: (json["confidence"] as? Double) ?? 0.5,
            missingInfo: (json["missing_info"] as? [String]) ?? []
        )
    }
}
