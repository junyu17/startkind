import Foundation

/// Cross-device sync abstraction. Free is local-only; Plus syncs via Supabase.
/// MVP: full push (upsert all local rows) + full pull, last-write-wins on
/// `updated_at` for mutable entities, insert-only for immutable history.
protocol SyncService: Sendable {
    var isAvailable: Bool { get async }
    /// Push local `export` per table, then pull each table. Returns remote rows.
    @MainActor func syncAll(export: [String: [[String: Any]]], tables: [String]) async throws -> [String: [[String: Any]]]
}

/// Default local-only sync. No account, no network.
struct LocalOnlySync: SyncService {
    var isAvailable: Bool { false }
    @MainActor func syncAll(export: [String: [[String: Any]]], tables: [String]) async throws -> [String: [[String: Any]]] {
        [:]
    }
}

/// Supabase sync. When configured and authenticated, pushes all local rows and
/// pulls the user's rows (RLS-scoped). Full bidirectional entity sync with
/// last-write-wins; conflict resolution beyond LWW is a follow-up.
final class SupabaseSync: SyncService {
    private let supabase: SupabaseClient?

    init(supabase: SupabaseClient? = nil) {
        self.supabase = supabase
    }

    var isAvailable: Bool { get async { supabase?.isAuthenticated ?? false } }

    @MainActor func syncAll(export: [String: [[String: Any]]], tables: [String]) async throws -> [String: [[String: Any]]] {
        guard let supabase, supabase.isAuthenticated else { return [:] }
        // Push: upsert each table's local rows.
        for (table, rows) in export where !rows.isEmpty {
            try await supabase.upsert(table: table, rows: rows)
        }
        // Pull: fetch each table (RLS returns only the user's rows).
        var remote: [String: [[String: Any]]] = [:]
        for table in tables {
            remote[table] = (try? await supabase.fetch(table: table)) ?? []
        }
        return remote
    }
}
