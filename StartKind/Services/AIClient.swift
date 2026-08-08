import Foundation

/// Abstraction over AI generation. Free uses deterministic local templates;
/// Plus routes through a cloud proxy (Supabase Edge Function) when configured
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

/// Cloud implementation. Calls Supabase Edge Functions when a configured,
/// authenticated client is available; otherwise falls back to local so the app
/// stays fully usable offline (per the architecture's graceful-degradation rule).
final class CloudAIClient: AIClient {
    private let fallback = LocalAIClient()
    private let supabase: SupabaseClient?

    init(supabase: SupabaseClient? = nil) {
        self.supabase = supabase
    }

    func generateNextStep(
        input: CaptureInput,
        calibrationMultiplier: Double
    ) async throws -> NextStepProposal {
        guard let supabase, supabase.isAuthenticated else {
            return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
        }
        do {
            let body: [String: Any] = [
                "input": input.rawText,
                "language": input.language,
                "calibrationMultiplier": calibrationMultiplier
            ]
            let json = try await supabase.invokeFunction("one_next_step", body: body)
            if let error = json["error"] as? String {
                if error == "limit_reached" { throw UsageError.stepLimitReached }
                // Other server errors: degrade to local.
                return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
            }
            if let proposal = Self.parseNextStep(json) { return proposal }
            return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
        } catch let usageError as UsageError {
            throw usageError
        } catch {
            return try await fallback.generateNextStep(input: input, calibrationMultiplier: calibrationMultiplier)
        }
    }

    func parseAdmin(text: String, language: String) async throws -> AdminParseResult {
        guard let supabase, supabase.isAuthenticated else {
            return try await fallback.parseAdmin(text: text, language: language)
        }
        do {
            let body: [String: Any] = ["text": text, "language": language]
            let json = try await supabase.invokeFunction("admin_task_reader", body: body)
            if let error = json["error"] as? String {
                if error == "plus_required" { throw UsageError.adminLimitReached }
                return try await fallback.parseAdmin(text: text, language: language)
            }
            if let result = Self.parseAdminResult(json) { return result }
            return try await fallback.parseAdmin(text: text, language: language)
        } catch let usageError as UsageError {
            throw usageError
        } catch {
            return try await fallback.parseAdmin(text: text, language: language)
        }
    }

    // MARK: - JSON parsing

    private static func parseNextStep(_ json: [String: Any]) -> NextStepProposal? {
        guard let title = json["title"] as? String,
              let step = json["step"] as? String else { return nil }
        let category = (json["category"] as? String).flatMap(TaskCategory.init(rawValue:)) ?? .other
        let shrink = (json["shrink_level"] as? Int).flatMap(ShrinkLevel.init(rawValue:)) ?? .zero
        let timer = (json["timer_minutes"] as? Int) ?? category.defaultEstimateMinutes
        return NextStepProposal(
            title: title,
            step: step,
            timerMinutes: max(1, min(25, timer)),
            stopCondition: (json["stop_condition"] as? String) ?? "",
            category: category,
            shrinkLevel: shrink,
            generatedBy: .cloudAI,
            whyThisStep: json["why_this_step"] as? String
        )
    }

    private static func parseAdminResult(_ json: [String: Any]) -> AdminParseResult? {
        let type = (json["artifact_type"] as? String).flatMap(AdminArtifactType.init(rawValue:)) ?? .other
        let nextJson = (json["one_next_step"] as? [String: Any]) ?? [:]
        let nextStep = NextStepProposal(
            title: (nextJson["title"] as? String) ?? "",
            step: (nextJson["step"] as? String) ?? "",
            timerMinutes: (nextJson["timer_minutes"] as? Int) ?? 5,
            stopCondition: (nextJson["stop_condition"] as? String) ?? "",
            category: .other,
            shrinkLevel: .one,
            generatedBy: .cloudAI
        )
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
