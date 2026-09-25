import SwiftUI

enum StartKindLegalLinks {
    static let privacy = "https://junyu17.github.io/startkind/privacy.html"
    static let terms = "https://junyu17.github.io/startkind/#terms"
}

/// Privacy & support page (App Review requires an accessible privacy policy).
struct PrivacyView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing16) {
                section(L("privacy.principlesTitle"), items: [
                    L("privacy.principle1"),
                    L("privacy.principle2"),
                    L("privacy.principle3")
                ])
                section(L("privacy.dataTitle"), items: [
                    L("privacy.data1"),
                    L("privacy.data2"),
                    L("privacy.data3"),
                    L("privacy.data4")
                ])
                section(L("privacy.controlsTitle"), items: [
                    L("privacy.control1"),
                    L("privacy.control2"),
                    L("privacy.control3"),
                    L("privacy.control4")
                ])
                section(L("privacy.sensitiveTitle"), items: [
                    L("privacy.sensitive1"),
                    L("privacy.sensitive2")
                ])

                legalLinks

                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    Text(verbatim: L("privacy.contactTitle")).font(.headline)
                    Button {
                        if let url = URL(string: "mailto:" + L("settings.contactEmail")) { openURL(url) }
                    } label: {
                        Text(verbatim: L("settings.contactEmail"))
                            .foregroundStyle(Theme.accent)
                            .accessibilityIdentifier("privacy.email")
                    }
                }
                .padding(.top, Theme.spacing8)

                Text(verbatim: L("settings.medical.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(L("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: L("privacy.legalTitle")).font(.headline)
            Button {
                open(StartKindLegalLinks.privacy)
            } label: {
                Label(L("privacy.fullPolicy"), systemImage: "arrow.up.right.square")
            }
            .accessibilityIdentifier("privacy.policy")
            Button {
                open(StartKindLegalLinks.terms)
            } label: {
                Label(L("legal.terms"), systemImage: "arrow.up.right.square")
            }
            .accessibilityIdentifier("privacy.terms")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func open(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        openURL(url)
    }

    @ViewBuilder
    private func section(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: title).font(.headline)
            ForEach(items, id: \.self) { item in
                Text(verbatim: "• " + item).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
