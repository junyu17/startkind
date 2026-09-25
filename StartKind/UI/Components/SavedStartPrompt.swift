import SwiftUI

struct SavedStartDraft: Identifiable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let category: TaskCategory?

    init(id: UUID = UUID(), title: String, body: String, category: TaskCategory?) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
    }

    init(proposal: NextStepProposal) {
        self.init(id: proposal.id, title: proposal.title, body: proposal.step, category: proposal.category)
    }
}

/// Keeps the decision to save a completed start separate from timer UI state.
/// A completed reduced rung passes `isRootFinished == false` and therefore
/// never produces a Saved starts prompt.
enum SavedStartCompletionPolicy {
    @MainActor
    static func draft(
        outcome: TimerOutcome,
        isRootFinished: Bool,
        proposal: NextStepProposal,
        vault: PersonalVaultStore
    ) -> SavedStartDraft? {
        guard outcome == .completed,
              isRootFinished,
              !vault.containsEquivalent(title: proposal.title, body: proposal.step) else {
            return nil
        }
        return SavedStartDraft(proposal: proposal)
    }
}

struct SavedStartConfirmationBanner: View {
    let title: String
    let onViewSaved: () -> Void

    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        HStack(alignment: .center, spacing: Theme.spacing10) {
            Label(L("savedStart.confirmed", title), systemImage: "bookmark.fill")
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.spacing4)
            Button(L("savedStart.view")) {
                onViewSaved()
            }
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("savedStart.view")
        }
        .padding(.horizontal, Theme.spacing12)
        .padding(.vertical, Theme.spacing10)
        .background(Theme.softAccent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("savedStart.confirmation")
    }
}
