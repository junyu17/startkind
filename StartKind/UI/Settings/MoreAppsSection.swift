import SwiftUI

/// Cross-promotion: the developer's other iOS apps, listed in Settings > About.
/// App-referrer installs run close to App Store search in volume for this
/// developer, so every app in the lineup carries a "More apps" list of the rest.
struct CrossPromoApp: Identifiable {
    let id: String
    let name: String
    let taglineKey: String
    let storeURL: URL
}

let otherDeveloperApps: [CrossPromoApp] = [
    CrossPromoApp(
        id: "taskkin",
        name: "TaskKin",
        taglineKey: "settings.moreApps.taskkin",
        storeURL: AppStoreLinks.crossPromoURL(appID: "6794837934")
    ),
    CrossPromoApp(
        id: "maren",
        name: "Maren",
        taglineKey: "settings.moreApps.maren",
        storeURL: AppStoreLinks.crossPromoURL(appID: "6795029983")
    ),
    CrossPromoApp(
        id: "platepace",
        name: "PlatePace",
        taglineKey: "settings.moreApps.platepace",
        storeURL: AppStoreLinks.crossPromoURL(appID: "6799087226")
    ),
    CrossPromoApp(
        id: "livepet",
        name: "Live Pet AI",
        taglineKey: "settings.moreApps.livepet",
        storeURL: AppStoreLinks.crossPromoURL(appID: "6794836674")
    ),
    CrossPromoApp(
        id: "virtualpets",
        name: "Virtual Pets",
        taglineKey: "settings.moreApps.virtualpets",
        storeURL: AppStoreLinks.crossPromoURL(appID: "6784545568")
    ),
    CrossPromoApp(
        id: "dogcat",
        name: "Dog & Cat Nutrition Coach",
        taglineKey: "settings.moreApps.dogcat",
        storeURL: AppStoreLinks.crossPromoURL(appID: "6800743305")
    ),
]

/// A "More apps" Settings section. Each row opens the developer's other app
/// straight to its App Store page.
struct MoreAppsSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            ForEach(otherDeveloperApps) { app in
                Button {
                    openURL(app.storeURL)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.spacing4) {
                            Text(verbatim: app.name)
                                .foregroundStyle(.primary)
                            Text(verbatim: L(app.taglineKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.moreApps.\(app.id)")
            }
        } header: {
            Text(verbatim: L("settings.moreApps"))
        }
    }
}
