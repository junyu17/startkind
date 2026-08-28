import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var exportText: String?
    @State private var showExport = false
    @State private var restoring = false

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
                } header: {
                    Text(verbatim: L("settings.language"))
                }

                Section {
                    HStack {
                        Text(verbatim: L("settings.subscription"))
                        Spacer()
                        Text(verbatim: env.entitlement.state.displayName)
                            .foregroundStyle(.secondary)
                    }
                    if !env.isPlus {
                        Button(L("settings.subscription.plus")) { showPaywall = true }
                    }
                    Button(L("settings.subscription.restore")) {
                        restoring = true
                        Task {
                            await env.entitlement.restore()
                            await env.syncEntitlementToBackend()
                            restoring = false
                        }
                    }
                    .disabled(restoring)
                } header: {
                    Text(verbatim: L("settings.subscription"))
                }

                Section {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Text(verbatim: L("privacy.title"))
                    }
                    NavigationLink {
                        VaultManagementView(vault: env.vault)
                    } label: {
                        Text(verbatim: L("vault.title"))
                    }
                    Button(L("settings.dataExport")) {
                        exportText = env.exportJSON()
                        showExport = true
                    }
                    Button(L("settings.deleteAccount"), role: .destructive) {
                        showDeleteConfirm = true
                    }
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
            }
            .navigationTitle(L("settings.title"))
            .sheet(isPresented: $showPaywall) {
                PaywallView(trigger: .feature).environmentObject(env)
            }
            .sheet(isPresented: $showExport) {
                if let exportText { ExportView(text: exportText) }
            }
            .alert(L("settings.deleteAccount"), isPresented: $showDeleteConfirm) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("settings.deleteAccount"), role: .destructive) {
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
