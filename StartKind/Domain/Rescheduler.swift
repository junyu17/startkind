import Foundation

/// Why a step is being rescheduled. Never use shame language for any of these.
enum SkipReason: String, Sendable {
    case skipped, paused, tooLarge
}

/// Result of a no-shame reschedule: a smaller step plus a kind message.
struct RescheduleResult: Sendable {
    let proposal: NextStepProposal
    let message: String
}

/// No-Shame Rescheduler.
///
/// When a user skips, pauses, or finds a step too large, this offers a smaller
/// step instead of failure language. See `docs/PRODUCT_REQUIREMENTS.md` §3.
struct Rescheduler: Sendable {
    let shrinker: TaskShrinker

    init(shrinker: TaskShrinker = TaskShrinker()) {
        self.shrinker = shrinker
    }

    func reschedule(_ proposal: NextStepProposal, language: String, reason: SkipReason) -> RescheduleResult {
        let next = shrinker.nextLevel(after: proposal.shrinkLevel)
        let smaller = shrinker.shrink(proposal, to: next, language: language)
        return RescheduleResult(proposal: smaller, message: message(for: reason, language: language))
    }

    private func message(for reason: SkipReason, language: String) -> String {
        let zh = language.lowercased().hasPrefix("zh")
        switch reason {
        case .skipped:
            return zh
                ? "没关系。这里有个更轻的版本,留着以后。"
                : "No problem. Here's a lighter version for later."
        case .paused:
            return zh
                ? "已轻轻暂停。回来时这里有个更小的步骤。"
                : "Paused gently. A smaller step is here when you return."
        case .tooLarge:
            return zh
                ? "这一步现在可能有点大。试试更小的版本。"
                : "This step may be too large right now. Try the smaller version."
        }
    }
}
