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
    @FocusState private var focusedField: Field?

    enum Mode { case signIn, signUp }
    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing24) {
                header
                formPanel
            }
            .padding(.horizontal, Theme.spacing20)
            .padding(.vertical, Theme.spacing32)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing12) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(verbatim: L("auth.title"))
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
            }

            Text(verbatim: L("auth.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.spacing20)
    }

    private var formPanel: some View {
        VStack(spacing: Theme.spacing12) {
            emailField
            passwordField

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
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.switch")

            Button {
                env.skipAuth()
            } label: {
                Text(verbatim: L("auth.continueLocal"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.skip")
        }
        .startKindCard()
    }

    private var emailField: some View {
        FieldShell(systemImage: "envelope") {
            TextField(L("auth.email"), text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .accessibilityIdentifier("auth.email")

            Button {
                insertAtSign()
            } label: {
                Text(verbatim: "@")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.softAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "@"))
            .accessibilityIdentifier("auth.emailAt")
        }
    }

    private var passwordField: some View {
        FieldShell(systemImage: "lock") {
            SecureField(L("auth.password"), text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit {
                    guard !isLoading && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty else { return }
                    Task { await submit() }
                }
                .accessibilityIdentifier("auth.password")
        }
    }

    private func insertAtSign() {
        guard !email.contains("@") else {
            focusedField = .email
            return
        }
        email.append("@")
        focusedField = .email
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
