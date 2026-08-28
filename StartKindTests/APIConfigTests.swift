import XCTest
@testable import StartKind

/// If the endpoint fails to resolve, `StartKindAPI()` returns nil and every
/// cloud feature silently degrades to the local engine — the app still "works",
/// so nothing fails loudly. That is worth a test.
final class APIConfigTests: XCTestCase {

    func testSecretsPlistIsBundled() throws {
        let path = Bundle.main.path(forResource: "Secrets", ofType: "plist")
        XCTAssertNotNil(path, "Secrets.plist is missing from the app bundle")
        let dict = try XCTUnwrap(NSDictionary(contentsOfFile: try XCTUnwrap(path)) as? [String: String])
        XCTAssertNotNil(dict["STARTKIND_API_URL"], "STARTKIND_API_URL missing. Keys present: \(Array(dict.keys))")
    }

    func testBackendEndpointResolves() throws {
        let url = try XCTUnwrap(APIConfig.baseURL, "APIConfig.baseURL is nil — every cloud feature is disabled")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertNotNil(StartKindAPI(), "StartKindAPI() returned nil despite a configured base URL")
    }

    func testRequestPathsResolveAgainstTheBase() throws {
        let base = try XCTUnwrap(APIConfig.baseURL)
        let built = try XCTUnwrap(URL(string: "/v1/costart/rooms", relativeTo: base))
        XCTAssertEqual(built.absoluteString, "https://startk.livepet.ren/v1/costart/rooms")
    }
}
