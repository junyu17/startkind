import Foundation

/// Supabase project configuration.
///
/// Values are loaded from a non-committed `Secrets.plist` or Info.plist build
/// settings. When `endpoint` is nil, cloud features stay OFF and the app uses
/// its local engine/sync (graceful offline degradation per the architecture doc).
/// Never hardcode service-role keys here - the app only ever holds the anon key.
enum SupabaseConfig {
    static let endpoint: URL? = load(key: "SUPABASE_URL").flatMap { URL(string: $0) }
    static let anonKey: String? = load(key: "SUPABASE_ANON_KEY")

    static var isConfigured: Bool { endpoint != nil && anonKey != nil }

    private static func load(key: String) -> String? {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
            return dict[key]
        }
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
