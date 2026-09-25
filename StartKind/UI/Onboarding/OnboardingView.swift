import SwiftUI

struct OnboardingView: View {
    private enum Page: Equatable {
        case name
        case difficulty
    }

    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let isEditing: Bool

    @State private var page: Page = .name
    @State private var firstName = ""
    @State private var difficulty: StartDifficulty?
    @State private var didLoadExistingProfile = false
    @FocusState private var nameFocused: Bool

    init(isEditing: Bool = false) {
        self.isEditing = isEditing
    }

    private var nameIsValid: Bool {
        OnboardingProfileStore.isValidFirstName(firstName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing20) {
                    progressLabel
                    if page == .name {
                        namePage
                    } else {
                        difficultyPage
                    }
                }
                .padding(Theme.spacing20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L(isEditing ? "profile.title" : "onboarding.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("common.close")) { dismiss() }
                            .accessibilityIdentifier("onboarding.close")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("common.done")) { nameFocused = false }
                        .accessibilityIdentifier("onboarding.keyboard.done")
                }
            }
            .onAppear {
                guard isEditing, !didLoadExistingProfile else { return }
                didLoadExistingProfile = true
                firstName = env.onboarding.firstName
                difficulty = env.onboarding.difficulty
            }
        }
    }

    private var progressLabel: some View {
        Text(verbatim: L(page == .name ? "onboarding.progress.name" : "onboarding.progress.difficulty"))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.accent)
            .textCase(.uppercase)
            .accessibilityIdentifier("onboarding.progress")
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Text(verbatim: L("onboarding.name.title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                Text(verbatim: L("onboarding.name.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(L("onboarding.name.placeholder"), text: $firstName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($nameFocused)
                .accessibilityLabel(Text(verbatim: L("onboarding.name.label")))
                .accessibilityIdentifier("onboarding.name")
                .onSubmit { goToDifficultyIfValid() }

            HStack {
                Text(verbatim: L("onboarding.name.count", firstName.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if !firstName.isEmpty && !nameIsValid {
                Text(verbatim: L("onboarding.name.tooLong"))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding.name.error")
            }

            PrimaryButton(
                "onboarding.continue",
                systemImage: "arrow.right",
                enabled: nameIsValid,
                accessibilityId: "onboarding.name.next"
            ) {
                goToDifficultyIfValid()
            }
        }
    }

    private var difficultyPage: some View {
        VStack(alignment: .leading, spacing: Theme.spacing16) {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Text(verbatim: L("onboarding.difficulty.title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                Text(verbatim: L("onboarding.difficulty.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Theme.spacing8) {
                ForEach(StartDifficulty.allCases) { option in
                    Button {
                        difficulty = option
                    } label: {
                        HStack(spacing: Theme.spacing12) {
                            Image(systemName: option.systemImage)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: Theme.spacing4) {
                                Text(verbatim: L(option.titleKey))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.ink)
                                Text(verbatim: L(option.detailKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: Theme.spacing8)
                            Image(systemName: difficulty == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(difficulty == option ? Theme.accent : Color.secondary)
                        }
                        .padding(.horizontal, Theme.spacing12)
                        .padding(.vertical, Theme.spacing10)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                        .background(difficulty == option ? Theme.softAccent : Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                                .stroke(difficulty == option ? Theme.accent.opacity(0.35) : Theme.line, lineWidth: 1)
                        )
                    }
                    .pressableCard()
                    .accessibilityLabel(Text(verbatim: L(option.titleKey)))
                    .accessibilityValue(Text(verbatim: L(difficulty == option ? "onboarding.choice.selected" : "onboarding.choice.notSelected")))
                    .accessibilityIdentifier("onboarding.difficulty.\(option.rawValue)")
                }
            }

            PrimaryButton(
                isEditing ? "profile.save" : "onboarding.finish",
                systemImage: "checkmark",
                enabled: difficulty != nil,
                accessibilityId: "onboarding.finish"
            ) {
                saveProfile()
            }

            if page == .difficulty {
                Button(L("onboarding.back")) {
                    page = .name
                    nameFocused = false
                }
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                .accessibilityIdentifier("onboarding.back")
            }
        }
    }

    private func goToDifficultyIfValid() {
        guard nameIsValid else { return }
        nameFocused = false
        page = .difficulty
    }

    private func saveProfile() {
        guard let difficulty,
              env.onboarding.save(firstName: firstName, difficulty: difficulty) else { return }
        if isEditing {
            dismiss()
        }
    }
}
