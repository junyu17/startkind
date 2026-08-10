import Foundation

struct AutopilotPlanner {
    func proposal(
        capsule: RecoveryCapsuleModel?,
        vaultItems: [VaultItem],
        templates: [MicroTemplate],
        currentHour: Int = Calendar.current.component(.hour, from: .now)
    ) -> NextStepProposal {
        if let capsule {
            var proposal = capsule.resumeProposal
            proposal.whyThisStep = capsule.returnNote.map { L("autopilot.why.note", $0) } ?? L("autopilot.why.recovery")
            proposal.timerMinutes = min(max(proposal.timerMinutes, 5), 10)
            return proposal
        }

        if let item = vaultItems.first {
            return NextStepProposal(
                title: item.title,
                step: item.body,
                timerMinutes: 5,
                stopCondition: L("autopilot.stop.saved"),
                category: item.category ?? .other,
                shrinkLevel: .one,
                whyThisStep: L("autopilot.why.vault")
            )
        }

        let templateId: String
        switch currentHour {
        case 5..<11:
            templateId = "appointment"
        case 11..<17:
            templateId = "email"
        case 17..<23:
            templateId = "home"
        default:
            templateId = "bad-day"
        }
        let template = templates.first(where: { $0.id == templateId }) ?? templates.first
        return template?.proposal ?? NextStepProposal(
            title: L("autopilot.default.title"),
            step: L("autopilot.default.step"),
            timerMinutes: 5,
            stopCondition: L("autopilot.default.stop"),
            category: .other,
            shrinkLevel: .one,
            whyThisStep: L("autopilot.why.default")
        )
    }
}
