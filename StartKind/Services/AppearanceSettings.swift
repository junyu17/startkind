import SwiftUI

/// Display preferences the person controls themselves.
///
/// Both matter for this audience: a dark screen is easier late at night when
/// starting is hardest, and text size is the difference between a step being
/// readable and being skipped.
enum AppearanceTheme: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }
    var localizationKey: String { "settings.theme.\(rawValue)" }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppearanceTextSize: String, CaseIterable, Identifiable, Sendable {
    case standard, large, larger, largest

    var id: String { rawValue }
    var localizationKey: String { "settings.textSize.\(rawValue)" }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .standard: return .large
        case .large: return .xLarge
        case .larger: return .xxLarge
        case .largest: return .accessibility1
        }
    }

    /// Relative sample used by the size picker so the choice is visible before
    /// it is made.
    var sampleScale: CGFloat {
        switch self {
        case .standard: return 1.0
        case .large: return 1.15
        case .larger: return 1.3
        case .largest: return 1.5
        }
    }
}

@MainActor
final class AppearanceSettings: ObservableObject {
    @Published var theme: AppearanceTheme {
        didSet { defaults.set(theme.rawValue, forKey: Self.themeKey) }
    }

    @Published var textSize: AppearanceTextSize {
        didSet { defaults.set(textSize.rawValue, forKey: Self.textSizeKey) }
    }

    private let defaults: UserDefaults
    private static let themeKey = "sk_appearance_theme"
    private static let textSizeKey = "sk_appearance_text_size"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.theme = defaults.string(forKey: Self.themeKey)
            .flatMap(AppearanceTheme.init(rawValue:)) ?? .system
        self.textSize = defaults.string(forKey: Self.textSizeKey)
            .flatMap(AppearanceTextSize.init(rawValue:)) ?? .standard
    }

    func reset() {
        theme = .system
        textSize = .standard
    }
}
