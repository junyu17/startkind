import Foundation

/// The languages StartKind composes *dynamic* copy in.
///
/// Static UI strings live in `Localizable.strings` and are reached through `L(_:)`.
/// This type is for text that is generated at runtime — next steps, shrink levels,
/// rescue messages, admin summaries — where the wording depends on values that
/// only exist once the user has typed or scanned something.
///
/// Before this existed the generators carried a `let zh = language.hasPrefix("zh")`
/// flag and chose between two literals, so any language that was not Chinese
/// silently received English. Modelling the choice as an enum means a new language
/// is a compile error at every call site rather than a quiet fallback.
enum ContentLanguage: String, Sendable, CaseIterable {
    case en
    case zhHans
    case zhHant
    case ja
    case ko

    /// Maps a stored language tag (`"en"`, `"zh-Hans"`, `"zh-Hant"`, `"ja"`,
    /// `"ko"`, or a system identifier like `"ja-JP"`) onto a supported content language.
    /// Anything unrecognised falls back to English, matching the UI bundle.
    init(_ language: String) {
        let lowered = language.lowercased().replacingOccurrences(of: "_", with: "-")
        if lowered.hasPrefix("zh") {
            // Traditional script: an explicit Hant tag, or a Taiwan / Hong Kong /
            // Macau region with no script (`zh-TW`, `zh-HK`, `zh-MO`).
            let traditional = lowered.contains("hant")
                || (!lowered.contains("hans")
                    && ["-tw", "-hk", "-mo"].contains { lowered.contains($0) })
            self = traditional ? .zhHant : .zhHans
        } else if lowered.hasPrefix("ja") {
            self = .ja
        } else if lowered.hasPrefix("ko") {
            self = .ko
        } else {
            self = .en
        }
    }

    /// Choose the wording for this language.
    ///
    /// Arguments are autoclosures so the string interpolation for the
    /// languages that were not selected is never evaluated.
    func pick(
        en english: @autoclosure () -> String,
        zh chinese: @autoclosure () -> String,
        zhHant traditional: @autoclosure () -> String,
        ja japanese: @autoclosure () -> String,
        ko korean: @autoclosure () -> String
    ) -> String {
        switch self {
        case .en: return english()
        case .zhHans: return chinese()
        case .zhHant: return traditional()
        case .ja: return japanese()
        case .ko: return korean()
        }
    }
}
