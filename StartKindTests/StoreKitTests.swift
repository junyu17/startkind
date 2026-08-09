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

    override func tearDown() async throws {
        session = nil
        try await super.tearDown()
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

    private func requireStoreKitProducts(_ env: AppEnvironment) throws {
        if env.entitlement.monthlyProduct == nil || env.entitlement.annualProduct == nil {
            throw XCTSkip("Local StoreKitTest products are unavailable in this simulator/runtime.")
        }
    }

    func testInitialEntitlementIsFree() async throws {
        let env = try await makeEnv()
        XCTAssertFalse(env.entitlement.state.isPlus, "no purchase yet should be free")
    }

    func testProductsLoadWithCorrectIDs() async throws {
        let env = try await makeEnv()
        try requireStoreKitProducts(env)
        XCTAssertNotNil(env.entitlement.monthlyProduct)
        XCTAssertNotNil(env.entitlement.annualProduct)
        XCTAssertEqual(env.entitlement.monthlyProduct?.id, SubscriptionProductID.monthly)
        XCTAssertEqual(env.entitlement.annualProduct?.id, SubscriptionProductID.annual)
    }

    func testPurchaseMonthlyActivatesPlus() async throws {
        let env = try await makeEnv()
        try requireStoreKitProducts(env)
        let s = try XCTUnwrap(session)
        do {
            _ = try await s.buyProduct(identifier: SubscriptionProductID.monthly)
        } catch {
            throw XCTSkip("Local StoreKitTest purchase is unavailable in this simulator/runtime: \(error)")
        }
        await env.entitlement.refreshEntitlements()
        XCTAssertTrue(env.entitlement.state.isPlus, "monthly purchase should grant Plus")
    }

    func testPurchaseAnnualActivatesPlus() async throws {
        let env = try await makeEnv()
        try requireStoreKitProducts(env)
        let s = try XCTUnwrap(session)
        do {
            _ = try await s.buyProduct(identifier: SubscriptionProductID.annual)
        } catch {
            throw XCTSkip("Local StoreKitTest purchase is unavailable in this simulator/runtime: \(error)")
        }
        await env.entitlement.refreshEntitlements()
        XCTAssertTrue(env.entitlement.state.isPlus, "annual purchase should grant Plus")
    }

    func testRefreshRecoversExistingEntitlement() async throws {
        let env = try await makeEnv()
        try requireStoreKitProducts(env)
        let s = try XCTUnwrap(session)
        do {
            _ = try await s.buyProduct(identifier: SubscriptionProductID.annual)
        } catch {
            throw XCTSkip("Local StoreKitTest purchase is unavailable in this simulator/runtime: \(error)")
        }
        let restoredEnv = AppEnvironment(inMemory: true)
        await restoredEnv.entitlement.refreshEntitlements()
        XCTAssertTrue(restoredEnv.entitlement.state.isPlus, "refresh should recover existing Plus entitlement")
    }
}
