import Foundation

enum SupabaseError: Error {
    case notAuthenticated
    case badResponse
    case http(Int, String)
}

/// Lightweight Supabase client over URLSession (no SDK dependency).
/// Handles GoTrue auth (with access-token refresh), Edge Function invocation,
/// and PostgREST upsert/fetch. Until authenticated, callers fall back to local
/// so the app stays usable offline.
final class SupabaseClient: @unchecked Sendable {
    let endpoint: URL
    let anonKey: String
    private(set) var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?
    private let session: URLSession

    private static let accessKey = "sk_access_token"
    private static let refreshKey = "sk_refresh_token"
    private static let expiresKey = "sk_token_expires_at"

    init(endpoint: URL, anonKey: String, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.anonKey = anonKey
        self.session = session
        let defaults = UserDefaults.standard
        self.accessToken = defaults.string(forKey: Self.accessKey)
        self.refreshToken = defaults.string(forKey: Self.refreshKey)
        if let t = defaults.object(forKey: Self.expiresKey) as? Double {
            self.expiresAt = Date(timeIntervalSince1970: t)
        }
    }

    var isAuthenticated: Bool { accessToken != nil }

    // MARK: - Session storage

    private func storeSession(_ json: [String: Any]) {
        accessToken = json["access_token"] as? String
        refreshToken = json["refresh_token"] as? String
        if let exp = json["expires_at"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: exp)
        } else if let expiresIn = json["expires_in"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + expiresIn)
        }
        persistSession()
    }

    private func persistSession() {
        let defaults = UserDefaults.standard
        if let accessToken { defaults.set(accessToken, forKey: Self.accessKey) } else { defaults.removeObject(forKey: Self.accessKey) }
        if let refreshToken { defaults.set(refreshToken, forKey: Self.refreshKey) } else { defaults.removeObject(forKey: Self.refreshKey) }
        if let expiresAt { defaults.set(expiresAt.timeIntervalSince1970, forKey: Self.expiresKey) } else { defaults.removeObject(forKey: Self.expiresKey) }
    }

    /// Refresh the access token if it is missing or about to expire (60s margin).
    func ensureValidToken() async throws {
        guard accessToken != nil else { throw SupabaseError.notAuthenticated }
        let needsRefresh = expiresAt.map { $0.addingTimeInterval(-60) < Date() } ?? true
        guard needsRefresh else { return }
        guard let refreshToken else { throw SupabaseError.notAuthenticated }
        let json = try await post("/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": refreshToken])
        storeSession(json)
    }

    // MARK: - Auth (GoTrue REST)

    func signUp(email: String, password: String) async throws {
        let json = try await post("/auth/v1/signup", body: ["email": email, "password": password])
        storeSession(json)
    }

    func signIn(email: String, password: String) async throws {
        let json = try await post("/auth/v1/token?grant_type=password", body: ["email": email, "password": password])
        storeSession(json)
    }

    /// Anonymous sign-in for guest co-start join (no account required).
    func anonymousSignIn() async throws {
        let json = try await post("/auth/v1/signup", body: [:])
        storeSession(json)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        persistSession()
    }

    // MARK: - Edge Functions

    func invokeFunction(_ name: String, body: [String: Any]) async throws -> [String: Any] {
        try await ensureValidToken()
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        var req = URLRequest(url: endpoint.appendingPathComponent("functions/v1/\(name)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await sendJSON(req)
    }

    // MARK: - REST (PostgREST)

    @MainActor func upsert(table: String, rows: [[String: Any]]) async throws {
        try await ensureValidToken()
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        var req = URLRequest(url: endpoint.appendingPathComponent("rest/v1/\(table)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("return=minimal, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: rows)
        _ = try await sendData(req)
    }

    @MainActor func fetch(table: String) async throws -> [[String: Any]] {
        try await ensureValidToken()
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        var req = URLRequest(url: endpoint.appendingPathComponent("rest/v1/\(table)"))
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await sendJSONArray(req)
    }

    /// Fetch rows with a PostgREST filter, e.g. query ["room_id": "eq.<uuid>"].
    @MainActor func fetch(table: String, query: [String: String]) async throws -> [[String: Any]] {
        try await ensureValidToken()
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        var components = URLComponents(url: endpoint.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw SupabaseError.badResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await sendJSONArray(req)
    }

    /// Patch rows matching a PostgREST filter (e.g. update co-start participant outcome).
    @MainActor func patch(table: String, query: [String: String], values: [String: Any]) async throws {
        try await ensureValidToken()
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        var components = URLComponents(url: endpoint.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw SupabaseError.badResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: values)
        _ = try await sendData(req)
    }

    /// Returns the authenticated user's id from GoTrue.
    func getCurrentUserId() async throws -> String {
        try await ensureValidToken()
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        var req = URLRequest(url: endpoint.appendingPathComponent("auth/v1/user"))
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let json = try await sendJSON(req)
        guard let id = json["id"] as? String else { throw SupabaseError.badResponse }
        return id
    }

    // MARK: - HTTP helpers

    private func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: endpoint.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await sendJSON(req)
    }

    private func sendJSON(_ req: URLRequest) async throws -> [String: Any] {
        let data = try await sendData(req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseError.badResponse
        }
        return json
    }

    private func sendJSONArray(_ req: URLRequest) async throws -> [[String: Any]] {
        let data = try await sendData(req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SupabaseError.badResponse
        }
        return json
    }

    private func sendData(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.badResponse }
        if !(200..<300).contains(http.statusCode) {
            throw SupabaseError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
