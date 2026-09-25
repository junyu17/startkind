import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case limitReached
    case plusRequired
    case roomNotFound
    case codeUnavailable
    case notHost
    case network
    case server

    var errorDescription: String? {
        switch self {
        case .notConfigured: return L("error.api.notConfigured")
        case .limitReached: return L("error.usage.stepLimit")
        case .plusRequired: return L("error.usage.adminLimit")
        case .roomNotFound: return L("costart.roomNotFound")
        case .codeUnavailable: return L("costart.createError")
        case .notHost: return L("common.error")
        case .network: return L("error.auth.network")
        case .server: return L("common.error")
        }
    }
}

/// A co-start room as the server describes it.
struct RemoteRoom: Sendable {
    let id: UUID
    let code: String?
    let durationMinutes: Int
    let status: String
    let startsAt: Date

    init?(json: [String: Any]) {
        guard let idString = json["id"] as? String, let id = UUID(uuidString: idString) else { return nil }
        self.id = id
        self.code = json["code"] as? String
        self.durationMinutes = json["duration_minutes"] as? Int ?? 25
        self.status = json["status"] as? String ?? "active"
        self.startsAt = (json["starts_at"] as? String).flatMap(RemoteRoom.date) ?? .now
    }

    // Built per call rather than cached: ISO8601DateFormatter is not Sendable,
    // and this runs only when a room is created or joined.
    private static func date(_ value: String) -> Date? {
        if let plain = ISO8601DateFormatter().date(from: value) { return plain }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value)
    }
}

struct RemoteParticipant: Sendable {
    let id: String
    let displayName: String
    let statedStep: String
    let outcome: String?

    init(json: [String: Any]) {
        self.id = json["id"] as? String ?? UUID().uuidString
        self.displayName = json["display_name"] as? String ?? ""
        self.statedStep = json["stated_step"] as? String ?? ""
        self.outcome = json["outcome"] as? String
    }
}

/// Client for the StartKind backend.
///
/// The backend holds no personal data: task history lives in the user's own
/// iCloud. All this talks to is the AI proxy, co-start rooms, and receipt
/// verification. Identity is a single anonymous device token — no account, no
/// email, no password — stored in the Keychain and registered on first use.
actor StartKindAPI {
    private let baseURL: URL
    private let session: URLSession
    private static let tokenKey = "sk_device_token"

    private var cachedToken: String?

    init?(baseURL: URL? = APIConfig.baseURL, session: URLSession = .shared) {
        guard let baseURL else { return nil }
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Device token

    /// The device token, registering one the first time it is needed.
    private func token() async throws -> String {
        if let cachedToken { return cachedToken }
        if let stored = TokenStore.string(for: Self.tokenKey) {
            cachedToken = stored
            return stored
        }
        let issued = try await register()
        TokenStore.set(issued, for: Self.tokenKey)
        cachedToken = issued
        return issued
    }

    private func register() async throws -> String {
        let body = try await send(path: "/v1/device/register", method: "POST", json: [:], authorized: false)
        guard let token = body["token"] as? String, !token.isEmpty else { throw APIError.server }
        return token
    }

    /// Forget this device entirely. The next call registers a fresh anonymous
    /// identity; the previous server row is orphaned but not deleted, so do not
    /// describe this to the user as removing the server record.
    func resetDevice() {
        TokenStore.set(nil as String?, for: Self.tokenKey)
        cachedToken = nil
    }

    // MARK: - AI

    func nextStep(input: String, language: String, calibrationMultiplier: Double) async throws -> Data {
        try await sendRaw(path: "/v1/next-step", method: "POST", json: [
            "input": input,
            "language": language,
            "calibrationMultiplier": calibrationMultiplier
        ])
    }

    func adminParse(text: String, language: String) async throws -> Data {
        try await sendRaw(path: "/v1/admin-parse", method: "POST", json: [
            "text": text,
            "language": language
        ])
    }

    // MARK: - Entitlement

    @discardableResult
    func verifyTransaction(_ signedTransaction: String) async throws -> String {
        let body = try await send(path: "/v1/transaction", method: "POST", json: [
            "signedTransaction": signedTransaction
        ])
        return body["state"] as? String ?? "free"
    }

    // MARK: - Co-start

    func createRoom(stepText: String = "", displayName: String = "") async throws -> RemoteRoom {
        let body = try await send(path: "/v1/costart/rooms", method: "POST", json: [
            "step_text": stepText,
            "display_name": displayName
        ])
        guard let json = body["room"] as? [String: Any], let room = RemoteRoom(json: json) else {
            throw APIError.server
        }
        return room
    }

    func joinRoom(code: String, stepText: String, displayName: String) async throws -> RemoteRoom {
        let body = try await send(path: "/v1/costart/rooms/join", method: "POST", json: [
            "code": code,
            "step_text": stepText,
            "display_name": displayName
        ])
        guard let json = body["room"] as? [String: Any], let room = RemoteRoom(json: json) else {
            throw APIError.roomNotFound
        }
        return room
    }

    func participants(roomID: String) async throws -> [RemoteParticipant] {
        let body = try await send(path: "/v1/costart/rooms/\(roomID)/participants", method: "GET", json: nil)
        let raw = body["participants"] as? [[String: Any]] ?? []
        return raw.map(RemoteParticipant.init(json:))
    }

    func endRoom(roomID: String) async throws {
        _ = try await send(path: "/v1/costart/rooms/\(roomID)/end", method: "POST", json: [:])
    }

    func setOutcome(roomID: String, outcome: String) async throws {
        _ = try await send(path: "/v1/costart/rooms/\(roomID)/outcome", method: "POST", json: ["outcome": outcome])
    }

    // MARK: - Transport

    @discardableResult
    private func send(
        path: String,
        method: String,
        json: [String: Any]?,
        authorized: Bool = true
    ) async throws -> [String: Any] {
        let data = try await sendRaw(path: path, method: method, json: json, authorized: authorized)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private func sendRaw(
        path: String,
        method: String,
        json: [String: Any]?,
        authorized: Bool = true
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        if authorized {
            request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        if (200...299).contains(status) { return data }

        // A token the server no longer knows: drop it so the next call re-registers.
        if status == 401, authorized {
            resetDevice()
        }
        throw Self.error(status: status, code: body["error"] as? String)
    }

    private static func error(status: Int, code: String?) -> APIError {
        switch code {
        case "limit_reached": return .limitReached
        case "plus_required": return .plusRequired
        case "room_not_found": return .roomNotFound
        case "code_unavailable": return .codeUnavailable
        case "not_host", "not_a_participant": return .notHost
        default: return status >= 500 ? .server : .network
        }
    }
}

/// Backend endpoint. Absent in local-only builds, in which case every cloud
/// feature degrades to the on-device engine.
enum APIConfig {
    static let baseURL: URL? = {
        guard let raw = value(for: "STARTKIND_API_URL"), let url = URL(string: raw) else { return nil }
        return url
    }()

    static var isConfigured: Bool { baseURL != nil }

    private static func value(for key: String) -> String? {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: String],
           let found = dict[key], !found.isEmpty {
            return found
        }
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
