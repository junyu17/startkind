import Foundation
import Combine

struct VaultItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var category: TaskCategory?
    var createdAt: Date

    init(id: UUID = UUID(), title: String, body: String, category: TaskCategory? = nil, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.createdAt = createdAt
    }
}

@MainActor
final class PersonalVaultStore: ObservableObject {
    @Published private(set) var items: [VaultItem]

    private let defaults: UserDefaults
    private let key = "sk_personal_vault_items"
    private let limit = 24

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(defaults: defaults, key: key)
    }

    @discardableResult
    func add(title: String, body: String, category: TaskCategory?) -> VaultItem {
        let cleanTitle = normalized(title, fallback: L("vault.defaultTitle"))
        let item = VaultItem(
            title: cleanTitle,
            body: normalized(body, fallback: cleanTitle),
            category: category
        )
        items.removeAll { isEquivalent($0, item) }
        items.insert(item, at: 0)
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        persist()
        return item
    }

    func containsEquivalent(title: String, body: String) -> Bool {
        let cleanTitle = normalized(title, fallback: L("vault.defaultTitle"))
        let cleanBody = normalized(body, fallback: cleanTitle)
        return items.contains {
            comparisonKey(title: $0.title, body: $0.body) == comparisonKey(title: cleanTitle, body: cleanBody)
        }
    }

    func delete(_ item: VaultItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    private func normalized(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(240))
    }

    private func isEquivalent(_ lhs: VaultItem, _ rhs: VaultItem) -> Bool {
        comparisonKey(title: lhs.title, body: lhs.body) == comparisonKey(title: rhs.title, body: rhs.body)
    }

    private func comparisonKey(title: String, body: String) -> String {
        [title, body]
            .map { value in
                value
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
                    .lowercased()
            }
            .joined(separator: "\u{1F}")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> [VaultItem] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VaultItem].self, from: data) else { return [] }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }
}
