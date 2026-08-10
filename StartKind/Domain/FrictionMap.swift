import Foundation

struct FrictionInsight: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let category: TaskCategory
    let blocker: BlockerReason?
    let suggestedStep: String
}

struct FrictionMap {
    func insights(capsules: [RecoveryCapsuleModel], snapshots: [CalibrationSnapshot]) -> [FrictionInsight] {
        var output: [FrictionInsight] = []
        let blockers = capsules.compactMap(\.blockerReason)
        if let commonBlocker = mostCommon(blockers) {
            output.append(
                FrictionInsight(
                    id: "blocker-\(commonBlocker.rawValue)",
                    title: L("friction.blocker.title", L(commonBlocker.localizationKey)),
                    body: L("friction.blocker.body"),
                    category: capsules.first(where: { $0.blockerReason == commonBlocker })?.resumeCategory ?? .other,
                    blocker: commonBlocker,
                    suggestedStep: suggestedStep(for: commonBlocker)
                )
            )
        }

        if let hardest = snapshots
            .filter({ $0.sampleCount >= 2 })
            .sorted(by: { lhs, rhs in
                if lhs.completionRate == rhs.completionRate {
                    return lhs.estimateMultiplier > rhs.estimateMultiplier
                }
                return lhs.completionRate < rhs.completionRate
            })
            .first {
            output.append(
                FrictionInsight(
                    id: "category-\(hardest.category.rawValue)",
                    title: L("friction.category.title", L(hardest.category.localizationKey)),
                    body: L("friction.category.body"),
                    category: hardest.category,
                    blocker: nil,
                    suggestedStep: L("friction.category.step")
                )
            )
        }

        return Array(output.prefix(3))
    }

    private func mostCommon(_ blockers: [BlockerReason]) -> BlockerReason? {
        Dictionary(grouping: blockers, by: { $0 })
            .mapValues(\.count)
            .max { $0.value < $1.value }?
            .key
    }

    private func suggestedStep(for blocker: BlockerReason) -> String {
        switch blocker {
        case .needLogin:
            return L("friction.step.login")
        case .needDocument:
            return L("friction.step.document")
        case .tooVague:
            return L("friction.step.vague")
        case .tooBig:
            return L("friction.step.big")
        case .emotionallyHard:
            return L("friction.step.emotion")
        case .needAnotherPerson:
            return L("friction.step.person")
        }
    }
}
