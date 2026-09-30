import Foundation
import SwiftUI

/// Manages the active display language at runtime and provides a language-aware
/// bundle so the in-app language picker switches the UI live (no restart).
///
/// Not MainActor-bound: `bundle` lookups are thread-safe, and `setLanguage` is
/// only invoked from the UI (main thread), so @Published updates land on main.
final class LocalizationManager: ObservableObject {
    nonisolated(unsafe) static let shared = LocalizationManager()

    @Published private(set) var language: String
    @Published private(set) var locale: Locale

    init() {
        let lang = Self.normalize(Locale.preferredLanguages.first ?? "en")
        self.language = lang
        self.locale = Locale(identifier: lang)
    }

    /// The bundle for the currently active language (falls back to main).
    var bundle: Bundle {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let lprojBundle = Bundle(path: path) {
            return lprojBundle
        }
        return Bundle.main
    }

    func setLanguage(_ language: String) {
        let normalized = Self.normalize(language)
        self.language = normalized
        self.locale = Locale(identifier: normalized)
    }

    /// The app ships English, Simplified and Traditional Chinese, Japanese, and
    /// Korean; anything else falls back to English.
    private static func normalize(_ language: String) -> String {
        switch ContentLanguage(language) {
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .ja: return "ja"
        case .ko: return "ko"
        case .en: return "en"
        }
    }

    /// Localized string for `key` in the active language, with format args.
    func l(_ key: String, _ args: [CVarArg] = []) -> String {
        let template = NSLocalizedString(key, bundle: bundle, value: key, comment: "")
        return args.isEmpty ? template : String(format: template, arguments: args)
    }
}

/// Global localized-string helper. Reads the active language bundle from the
/// shared LocalizationManager. Safe to call from view bodies and initializers.
func L(_ key: String, _ args: CVarArg...) -> String {
    LocalizationManager.shared.l(key, args)
}
