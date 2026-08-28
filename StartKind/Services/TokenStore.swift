import Foundation
import Security

/// Keychain-backed storage for the anonymous backend device token.
///
/// Tokens previously lived in UserDefaults, which is a plain plist inside the
/// app container and is included in unencrypted backups. They belong in the
/// Keychain, pinned to this device and unavailable before first unlock.
enum TokenStore {
    private static let service = "ren.startkind.api"

    static func string(for key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String?, for key: String) {
        let query = baseQuery(key)
        guard let value, let data = value.data(using: .utf8) else {
            SecItemDelete(query as CFDictionary)
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess { return }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func double(for key: String) -> Double? {
        string(for: key).flatMap(Double.init)
    }

    static func set(_ value: Double?, for key: String) {
        set(value.map { String($0) }, for: key)
    }

    /// One-time move of tokens written by earlier builds into the Keychain.
    static func migrateFromUserDefaults(keys: [String]) {
        let defaults = UserDefaults.standard
        for key in keys {
            defer { defaults.removeObject(forKey: key) }
            guard string(for: key) == nil else { continue }
            if let text = defaults.string(forKey: key) {
                set(text, for: key)
            } else if let number = defaults.object(forKey: key) as? Double {
                set(number, for: key)
            }
        }
    }

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
