import XCTest
import StoreKitTest
@testable import StartKind

/// StoreKit local tests using the StoreKitTest framework + Products.storekit.
///
/// Loads the checked-in `.storekit` file directly so purchase/restore tests fail
/// if local products stop resolving.
@MainActor
final class StoreKitTests: XCTestCase {
    private var session: SKTestSession?

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    @discardableResult
    private func makeEnv() async throws -> AppEnvironment {
        XCTAssertNotNil(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let s = try SKTestSession(configurationFileNamed: "Products")
        s.disableDialogs = true
        s.clearTransactions()
        session = s
        let env = AppEnvironment(inMemory: true)
        await env.entitlement.load()
        return env
    }

    func testInitialEntitlementIsFree() async throws {
        let env = try await makeEnv()
        XCTAssertFalse(env.entitlement.state.isPlus, "no purchase yet should be free")
    }

    func testProductsLoadWithCorrectIDs() async throws {
        let env = try await makeEnv()
        XCTAssertNotNil(env.entitlement.monthlyProduct)
        XCTAssertNotNil(env.entitlement.annualProduct)
        XCTAssertEqual(env.entitlement.monthlyProduct?.id, SubscriptionProductID.monthly)
        XCTAssertEqual(env.entitlement.annualProduct?.id, SubscriptionProductID.annual)
    }

    func testPurchaseMonthlyActivatesPlus() async throws {
        let env = try await makeEnv()
        let monthly = try XCTUnwrap(env.entitlement.monthlyProduct)
        let success = await env.entitlement.purchase(monthly)
        XCTAssertTrue(success, "purchase should succeed")
        XCTAssertTrue(env.entitlement.state.isPlus, "monthly purchase should grant Plus")
    }

    func testPurchaseAnnualActivatesPlus() async throws {
        let env = try await makeEnv()
        let annual = try XCTUnwrap(env.entitlement.annualProduct)
        let success = await env.entitlement.purchase(annual)
        XCTAssertTrue(success)
        XCTAssertTrue(env.entitlement.state.isPlus, "annual purchase should grant Plus")
    }

    func testRestoreRecoversEntitlement() async throws {
        let env = try await makeEnv()
        let annual = try XCTUnwrap(env.entitlement.annualProduct)
        _ = await env.entitlement.purchase(annual)
        await env.entitlement.restore()
        XCTAssertTrue(env.entitlement.state.isPlus, "restore should recover Plus")
    }
}
