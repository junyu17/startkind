import SwiftUI

/// Centralized visual theme for StartKind.
///
/// Design goal: quiet, clear, immediately usable. One calm accent color,
/// high-contrast text, large tap targets, small radii. No shame colors.
struct Theme {
    /// Calm accent (deep teal-green). Conveys steadiness, not urgency.
    static let accent = Color("AccentColor")
    /// Near-white surface in light mode, soft near-black in dark mode.
    static let background = Color("BackgroundColor")

    // MARK: Spacing
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40

    // MARK: Radii (kept small per UX spec)
    static let radius8: CGFloat = 8
    static let radius12: CGFloat = 12
    static let radius16: CGFloat = 16

    // MARK: Tap targets
    static let minTapTarget: CGFloat = 44

    /// A neutral, non-punitive color used for "paused / gentle" states.
    static let gentleMuted = Color.secondary
}

extension View {
    /// Apply a consistent quiet card style.
    func startKindCard() -> some View {
        self
            .padding(Theme.spacing16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
    }
}
