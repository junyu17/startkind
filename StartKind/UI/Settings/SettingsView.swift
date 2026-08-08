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
                    if env.isSignedIn {
                        Label(L("settings.signedIn"), systemImage: "checkmark.seal.fill")
                        Button(L("settings.signOut"), role: .destructive) { env.signOut() }
                    } else {
                        Label(L("settings.signedOutLocal"), systemImage: "iphone")
                        Button(L("settings.signIn")) { env.resetToAuth() }
                    }
                } header: {
                    Text(verbatim: L("settings.account"))
                }

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
                    LabeledContent(L("settings.contact"), value: "billy.yu@me.com")
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

struct ExportView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(verbatim: text)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(L("settings.dataExport"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}
