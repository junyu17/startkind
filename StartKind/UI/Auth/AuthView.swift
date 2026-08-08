import SwiftUI

/// Sign-in / sign-up screen shown before entering the app. Users can also skip
/// and use the app locally (Free, no account) - per the privacy model.
struct AuthView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager

    @State private var email = ""
    @State private var password = ""
    @State private var mode: Mode = .signIn
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case signIn, signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing20) {
                VStack(spacing: Theme.spacing12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, Theme.spacing40)
                    Text(verbatim: L("auth.title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(verbatim: L("auth.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Theme.spacing12) {
                    TextField(L("auth.email"), text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("auth.email")
                    SecureField(L("auth.password"), text: $password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("auth.password")
                }

                if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PrimaryButton(
                    mode == .signIn ? "auth.signIn" : "auth.signUp",
                    enabled: !isLoading && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty,
                    accessibilityId: "auth.submit"
                ) {
                    Task { await submit() }
                }

                Button {
                    mode = (mode == .signIn) ? .signUp : .signIn
                    errorMessage = nil
                } label: {
                    Text(verbatim: L(mode == .signIn ? "auth.switchToSignUp" : "auth.switchToSignIn"))
                        .font(.footnote)
                        .frame(minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("auth.switch")

                Button {
                    env.skipAuth()
                } label: {
                    Text(verbatim: L("auth.continueLocal"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("auth.skip")
                .padding(.bottom, Theme.spacing24)
            }
            .padding(.horizontal)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if mode == .signIn {
                try await env.signIn(email: email, password: password)
            } else {
                try await env.signUp(email: email, password: password)
            }
        } catch let authError as AuthError {
            errorMessage = (authError == .invalidCredentials) ? L("auth.error") : L("common.error")
        } catch {
            errorMessage = L("common.error")
        }
        isLoading = false
    }
}
