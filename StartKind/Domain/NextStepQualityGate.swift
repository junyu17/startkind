import Foundation

enum NextStepQualityRejection: Equatable, Sendable {
    case emptyTitle
    case emptyStep
    case emptyStopCondition
    case timerOutOfRange
    case listLike
    case legacyGenericFallback
    case vagueNonAction
    case missingTaskAnchor
}

/// Shared deterministic validation for generated one-next-step content.
///
/// The gate is intentionally conservative about structure and intent
/// preservation, but only checks anchors when the parser is confident. This
/// keeps short function-word inputs and languages without reliable token
/// boundaries from being rejected for the wrong reason.
struct NextStepQualityGate: Sendable {
    init() {}

    static func rejectionReason(
        for proposal: NextStepProposal,
        intent: TaskIntent? = nil,
        freshStep: Bool = true
    ) -> NextStepQualityRejection? {
        if proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyTitle
        }
        if proposal.step.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyStep
        }
        if proposal.stopCondition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyStopCondition
        }
        if freshStep && !(5...15).contains(proposal.timerMinutes) {
            return .timerOutOfRange
        }

        let response = [proposal.title, proposal.step, proposal.stopCondition].joined(separator: " ")
        if looksLikeList(response) {
            return .listLike
        }
        if containsLegacyGenericFallback(response) {
            return .legacyGenericFallback
        }
        if containsVagueNonAction(response) {
            return .vagueNonAction
        }
        let actionableResponse = [proposal.step, proposal.stopCondition].joined(separator: " ")
        if let intent, intent.hasConfidentAnchor, !intent.matchesAnchor(in: actionableResponse) {
            return .missingTaskAnchor
        }
        return nil
    }

    static func accepts(
        _ proposal: NextStepProposal,
        for intent: TaskIntent? = nil,
        freshStep: Bool = true
    ) -> Bool {
        rejectionReason(for: proposal, intent: intent, freshStep: freshStep) == nil
    }
}

private extension NextStepQualityGate {
    static let legacyGenericFallbackPhrases = [
        "name the smallest part",
        "say or write the smallest part",
        "open where this task lives",
        "open the app, message, document",
        "open the app, message, document, or physical item",
        "打开这件事所在的位置",
        "打开与这件事有关的 app、消息或文件"
    ]

    static func containsLegacyGenericFallback(_ text: String) -> Bool {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
        return legacyGenericFallbackPhrases.contains { normalized.contains($0) }
    }

    static let vagueNonActionPhrases = [
        "take one small, reversible action",
        "take one small action",
        "do one small, reversible action",
        "do a small, reversible action",
        "take a small, reversible step",
        "take the first small step",
        "do a small action",
        "做一个小的、可撤回的动作",
        "做一个小的可撤回的动作",
        "做一个小的动作",
        "做一个小动作",
        "可撤回的小动作"
    ]

    static func containsVagueNonAction(_ text: String) -> Bool {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
        return vagueNonActionPhrases.contains { normalized.contains($0) }
    }

    static func looksLikeList(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lines.count > 1 {
            let marked = lines.filter { line in
                line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") || isNumbered(line)
            }
            if !marked.isEmpty { return true }
        }

        var numberedMarkers = 0
        for marker in ["1. ", "1) ", "2. ", "2) ", "3. ", "3) "] {
            if text.contains(marker) { numberedMarkers += 1 }
        }
        return numberedMarkers >= 2
    }

    static func isNumbered(_ line: String) -> Bool {
        let characters = Array(line)
        var index = 0
        while index < characters.count, characters[index].isNumber {
            index += 1
        }
        guard index > 0, index + 1 < characters.count else { return false }
        guard characters[index] == "." || characters[index] == ")" else { return false }
        return characters[index + 1].isWhitespace
    }
}
