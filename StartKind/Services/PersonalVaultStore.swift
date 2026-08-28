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
        let item = VaultItem(
            title: normalized(title, fallback: L("vault.defaultTitle")),
            body: normalized(body, fallback: title),
            category: category
        )
        items.removeAll { $0.title == item.title && $0.body == item.body }
        items.insert(item, at: 0)
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        persist()
        return item
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
