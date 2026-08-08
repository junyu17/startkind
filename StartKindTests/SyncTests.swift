import XCTest
import SwiftData
@testable import StartKind

@MainActor
final class SyncTests: XCTestCase {
    private func makeService() throws -> PersistenceService { try PersistenceService(inMemory: true) }
    private func proposal(_ c: TaskCategory = .bills) -> NextStepProposal {
        NextStepProposal(title: "t", step: "s", timerMinutes: 10, stopCondition: "stop", category: c)
    }

    func testExportIncludesEntities() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        svc.upsertRecoveryCapsule(for: step, isPlus: false)
        let export = svc.syncExport(authUserId: svc.userId)
        XCTAssertFalse((export["user_profiles"] ?? []).isEmpty)
        XCTAssertFalse((export["next_steps"] ?? []).isEmpty)
        XCTAssertFalse((export["recovery_capsules"] ?? []).isEmpty)
    }

    func testImportInsertsIntoFreshStore() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        svc.upsertRecoveryCapsule(for: step, isPlus: false)
        let export = svc.syncExport(authUserId: UUID())

        let svc2 = try PersistenceService(inMemory: true)
        svc2.syncImport(export)
        XCTAssertNotNil(svc2.activeRecoveryCapsule(), "imported capsule should appear in fresh store")
    }

    func testLWWRemoteNewerOverwritesLocal() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        svc.upsertRecoveryCapsule(for: step, isPlus: false)
        var export = svc.syncExport(authUserId: svc.userId)
        guard var row = export["recovery_capsules"]?.first else { return XCTFail("no capsule row") }
        row["resume_title"] = "Remote wins"
        row["updated_at"] = SyncCoding.encode(Date().addingTimeInterval(3600)) as Any
        export["recovery_capsules"] = [row]
        svc.syncImport(export)
        XCTAssertEqual(svc.activeRecoveryCapsule()?.resumeTitle, "Remote wins")
    }

    func testLWOOlderRemoteDoesNotOverwrite() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        svc.upsertRecoveryCapsule(for: step, isPlus: false)
        let originalTitle = svc.activeRecoveryCapsule()?.resumeTitle
        var export = svc.syncExport(authUserId: svc.userId)
        guard var row = export["recovery_capsules"]?.first else { return XCTFail("no row") }
        row["resume_title"] = "Remote loses"
        row["updated_at"] = SyncCoding.encode(Date().addingTimeInterval(-3600)) as Any
        export["recovery_capsules"] = [row]
        svc.syncImport(export)
        XCTAssertEqual(svc.activeRecoveryCapsule()?.resumeTitle, originalTitle, "older remote must not overwrite local")
    }

    func testImportIsIdempotent() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        svc.upsertRecoveryCapsule(for: step, isPlus: false)
        let export = svc.syncExport(authUserId: svc.userId)
        svc.syncImport(export) // import back into same store (no-op for LWW same updated_at)
        svc.syncImport(export)
        XCTAssertNotNil(svc.activeRecoveryCapsule())
    }

    func testNextStepStatusSyncsViaLWW() throws {
        let svc = try makeService()
        let step = svc.saveNextStep(proposal: proposal(), capture: nil, taskTitle: "T")
        svc.startTimer(for: step, plannedMinutes: 10) // bumps updatedAt, status -> started
        var export = svc.syncExport(authUserId: svc.userId)
        guard var row = export["next_steps"]?.first else { return XCTFail("no next_step row") }
        row["title"] = "Remote updated step"
        row["status"] = "completed"
        row["updated_at"] = SyncCoding.encode(Date().addingTimeInterval(3600)) as Any
        export["next_steps"] = [row]
        svc.syncImport(export)
        let fetched = svc.fetchNextStep(id: step.id)
        XCTAssertEqual(fetched?.title, "Remote updated step")
        XCTAssertEqual(fetched?.status, .completed)
    }

    func testSupabaseFetchParsesPostgRESTArray() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.contains("/auth/v1/token") {
                return (200, [
                    "access_token": "access-token",
                    "refresh_token": "refresh-token",
                    "expires_in": 3600
                ])
            }
            if path.contains("/rest/v1/recovery_capsules") {
                return (200, [[
                    "id": UUID().uuidString,
                    "resume_title": "Remote row",
                    "updated_at": SyncCoding.encode(Date()) as Any
                ]])
            }
            return (404, ["error": "unexpected"])
        }

        let client = SupabaseClient(endpoint: URL(string: "https://example.supabase.co")!, anonKey: "anon", session: session)
        client.signOut()
        try await client.signIn(email: "test@example.com", password: "password")
        let rows = try await client.fetch(table: "recovery_capsules")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?["resume_title"] as? String, "Remote row")
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Any))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: SupabaseError.badResponse)
            return
        }
        do {
            let (status, json) = try handler(request)
            let data = try JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
