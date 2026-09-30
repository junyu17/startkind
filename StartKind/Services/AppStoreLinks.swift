import Foundation

/// The single place App Store links are built. Every link out of the app carries
/// the developer's provider token (`pt`) so App Store Connect can attribute the
/// install to a campaign (`ct`, at most 40 characters).
///
/// Campaign names are shared across the developer's apps so analytics line up:
/// `xp_<app slug>` for cross-promotion, `share_<artefact>` for shared content.
enum AppStoreLinks {
    static let providerToken = "129087449"
    static let appID = "6799113108"
    static let slug = "startkind"

    /// Campaign link to an app's App Store page.
    static func campaignURL(appID: String, campaign: String) -> URL {
        URL(string: "https://apps.apple.com/app/apple-store/id\(appID)?pt=\(providerToken)&ct=\(campaign)&mt=8")!
    }

    /// Link to a sibling app, tagged as cross-promotion from this app.
    static func crossPromoURL(appID: String) -> URL {
        campaignURL(appID: appID, campaign: "xp_\(slug)")
    }

    /// Link to this app, tagged with what was shared (`step`, `invite`, `app`, ...).
    static func shareURL(_ artefact: String) -> URL {
        campaignURL(appID: appID, campaign: "share_\(artefact)")
    }

    /// Opens the write-a-review page directly. Unlike the system prompt it is
    /// not capped at three appearances a year.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")!
}
