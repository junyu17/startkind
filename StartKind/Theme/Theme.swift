import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Centralized visual theme for StartKind.
///
/// Design goal: quiet, clear, immediately usable. One calm accent color,
/// high-contrast text, large tap targets, small radii. No shame colors.
struct Theme {
    /// Calm accent (deep teal-green). Conveys steadiness, not urgency.
    static let accent = Color("AccentColor")
    /// Near-white surface in light mode, soft near-black in dark mode.
    static let background = Color("BackgroundColor")
    static let surface = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.996, blue: 0.984, alpha: 1),
        dark: UIColor(red: 0.125, green: 0.129, blue: 0.122, alpha: 1)
    )
    static let surfaceRaised = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        dark: UIColor(red: 0.165, green: 0.169, blue: 0.160, alpha: 1)
    )
    static let line = adaptiveColor(
        light: UIColor(red: 0.859, green: 0.851, blue: 0.820, alpha: 1),
        dark: UIColor(red: 0.278, green: 0.286, blue: 0.267, alpha: 1)
    )
    static let softAccent = adaptiveColor(
        light: UIColor(red: 0.918, green: 0.961, blue: 0.929, alpha: 1),
        dark: UIColor(red: 0.137, green: 0.231, blue: 0.184, alpha: 1)
    )
    static let warmWash = adaptiveColor(
        light: UIColor(red: 0.984, green: 0.941, blue: 0.843, alpha: 1),
        dark: UIColor(red: 0.275, green: 0.220, blue: 0.145, alpha: 1)
    )
    static let ink = Color.primary
    /// Warm, high-contrast highlight reserved for the annual saving. It is the
    /// one place the UI is allowed to shout.
    static let savingHighlight = adaptiveColor(
        light: UIColor(red: 0.788, green: 0.361, blue: 0.106, alpha: 1),
        dark: UIColor(red: 0.929, green: 0.494, blue: 0.192, alpha: 1)
    )

    // MARK: Spacing
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing10: CGFloat = 10
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40

    // MARK: Radii (kept small per UX spec)
    static let radius8: CGFloat = 8
    static let radius12: CGFloat = 8
    static let radius16: CGFloat = 8

    // MARK: Tap targets
    static let minTapTarget: CGFloat = 44

    /// A neutral, non-punitive color used for "paused / gentle" states.
    static let gentleMuted = Color.secondary

    static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    /// Apply a consistent quiet card style.
    func startKindCard() -> some View {
        self
            .padding(Theme.spacing16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous)
                    .stroke(Theme.line.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}
