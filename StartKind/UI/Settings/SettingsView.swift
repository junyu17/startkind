import SwiftUI
import StoreKit
import UIKit

private enum SettingsSheet: Identifiable {
    case profile
    case paywall
    case export(String)

    var id: String {
        switch self {
        case .profile: return "profile"
        case .paywall: return "paywall"
        case .export: return "export"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var appearance: AppearanceSettings
    @State private var sheet: SettingsSheet?
    @State private var showDeleteConfirm = false
    @State private var restoring = false
    @State private var subscriptionFeedback: String?
    @State private var subscriptionFeedbackIsError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("settings.language"), selection: Binding(
                        get: { env.currentLanguage },
                        set: { env.setLanguage($0) }
                    )) {
                        Text(verbatim: L("settings.language.en")).tag("en")
                        Text(verbatim: L("settings.language.zh")).tag("zh-Hans")
                    }
                    .accessibilityIdentifier("settings.language")
                } header: {
                    Text(verbatim: L("settings.language"))
                }

                Section {
                    Button {
                        sheet = .profile
                    } label: {
                        Label(L("settings.editProfile"), systemImage: "person.crop.circle")
                    }
                    .accessibilityIdentifier("settings.editProfile")
                } header: {
                    Text(verbatim: L("settings.profile"))
                }

                Section {
                    Picker(L("settings.theme"), selection: $appearance.theme) {
                        ForEach(AppearanceTheme.allCases) { option in
                            Text(verbatim: L(option.localizationKey)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.theme")

                    VStack(alignment: .leading, spacing: Theme.spacing8) {
                        Picker(L("settings.textSize"), selection: $appearance.textSize) {
                            ForEach(AppearanceTextSize.allCases) { option in
                                Text(verbatim: L(option.localizationKey)).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("settings.textSize")

                        // Show the result before the choice is committed.
                        Text(verbatim: L("settings.textSize.sample"))
                            .font(.system(size: 15 * appearance.textSize.sampleScale))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.textSize.sample")
                    }
                } header: {
                    Text(verbatim: L("settings.display"))
                }

                Section {
                    HStack {
                        Text(verbatim: L("settings.subscription"))
                        Spacer()
                        Text(verbatim: env.entitlement.state.displayName)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("settings.subscription.status")
                    if !env.isPlus {
                        Button(L("settings.subscription.upgrade")) { sheet = .paywall }
                            .accessibilityIdentifier("settings.subscription.upgrade")
                    } else {
                        Button {
                            manageSubscriptions()
                        } label: {
                            Label(L("settings.subscription.manage"), systemImage: "arrow.up.right.square")
                        }
                        .accessibilityIdentifier("settings.subscription.manage")
                    }
                    Button {
                        subscriptionFeedback = nil
                        restoring = true
                        Task {
                            let restored = await env.entitlement.restore()
                            if let error = env.entitlement.lastError {
                                subscriptionFeedback = error
                                subscriptionFeedbackIsError = true
                            } else if restored {
                                await env.syncEntitlementToBackend()
                                subscriptionFeedback = L("settings.subscription.restore.success")
                                subscriptionFeedbackIsError = false
                            } else {
                                subscriptionFeedback = L("settings.subscription.restore.none")
                                subscriptionFeedbackIsError = false
                            }
                            restoring = false
                        }
                    } label: {
                        HStack(spacing: Theme.spacing8) {
                            if restoring { ProgressView().controlSize(.small) }
                            Text(verbatim: L("settings.subscription.restore"))
                        }
                    }
                    .disabled(restoring)
                    .accessibilityIdentifier("settings.subscription.restore")
                    if let subscriptionFeedback {
                        Text(verbatim: subscriptionFeedback)
                            .font(.footnote)
                            .foregroundStyle(subscriptionFeedbackIsError ? .orange : Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.subscription.feedback")
                    }
                } header: {
                    Text(verbatim: L("settings.subscription"))
                }

                Section {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Text(verbatim: L("privacy.title"))
                    }
                    .accessibilityIdentifier("settings.privacy")
                    NavigationLink {
                        VaultManagementView(vault: env.vault)
                    } label: {
                        Text(verbatim: L("vault.title"))
                    }
                    Button(L("settings.dataExport")) {
                        sheet = .export(env.exportJSON())
                    }
                    .accessibilityIdentifier("settings.dataExport")
                    Button(L("settings.deleteData"), role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .accessibilityIdentifier("settings.deleteData")
                } header: {
                    Text(verbatim: L("settings.privacy"))
                }

                Section {
                    LabeledContent(L("settings.contact"), value: L("settings.contactEmail"))
                    medicalRow
                    versionRow
                } header: {
                    Text(verbatim: L("settings.about"))
                }

                MoreAppsSection()
            }
            .navigationTitle(L("settings.title"))
            // One sheet driven by an item, so the content can never be built
            // from state that is still nil and present an empty sheet.
            .sheet(item: $sheet) { which in
                switch which {
                case .profile:
                    OnboardingView(isEditing: true).environmentObject(env)
                case .paywall:
                    PaywallView(trigger: .feature).environmentObject(env)
                case .export(let text):
                    ExportView(text: text)
                }
            }
            .alert(L("settings.deleteData"), isPresented: $showDeleteConfirm) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("settings.deleteData"), role: .destructive) {
                    env.deleteAllData()
                }
            } message: {
                Text(verbatim: L("settings.deleteConfirm.body"))
            }
        }
    }

    private var medicalRow: some View {
        VStack(alignment: .leading, spacing: Theme.spacing4) {
            Text(verbatim: L("settings.medical")).font(.subheadline)
            Text(verbatim: L("settings.medical.body"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var versionRow: some View {
        Text(verbatim: L("settings.version", Bundle.main.appVersion))
            .foregroundStyle(.secondary)
    }

    private func manageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            subscriptionFeedback = L("settings.subscription.manage.error")
            subscriptionFeedbackIsError = true
            return
        }

        Task { @MainActor in
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                subscriptionFeedback = error.localizedDescription
                subscriptionFeedbackIsError = true
            }
        }
    }
}

struct VaultManagementView: View {
    @ObservedObject var vault: PersonalVaultStore
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        List {
            if vault.items.isEmpty {
                ContentUnavailableView(
                    L("vault.empty.title"),
                    systemImage: "tray",
                    description: Text(verbatim: L("vault.empty.body"))
                )
            } else {
                ForEach(vault.items) { item in
                    VStack(alignment: .leading, spacing: Theme.spacing4) {
                        Text(verbatim: item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(verbatim: item.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let category = item.category {
                            Label(L(category.localizationKey), systemImage: category.systemImage)
                                .font(.caption2)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .accessibilityIdentifier("settings.vault.item")
                    .swipeActions {
                        Button(L("common.delete"), role: .destructive) {
                            vault.delete(item)
                        }
                    }
                }
            }
        }
        .navigationTitle(L("vault.title"))
    }
}

struct ExportView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(verbatim: text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(L("settings.dataExport"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("settings.dataExport.share")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}
