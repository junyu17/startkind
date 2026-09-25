import Foundation
import StoreKit

/// StoreKit 2 entitlement management.
///
/// Treats the App Store as the source of truth for entitlements. Plus cloud
/// features mirror this state to the backend so it can gate the AI proxy.
/// Never hardcodes shared secrets; only uses official StoreKit flows.
@MainActor
final class EntitlementService: ObservableObject {
    @Published private(set) var state: EntitlementState = .free
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productsLoadError: String?
    /// Apple-signed proof of the current Plus entitlement (StoreKit 2 JWS).
    /// The backend verifies this signature locally, so nothing here is trusted
    /// on the client's word.
    @Published private(set) var signedTransaction: String?
    @Published var lastError: String?

    private var updatesListener: Task<Void, Never>?

    init(forcePlusForUITest: Bool = false) {
#if DEBUG
        // This hook is only compiled into Debug builds and is used by UI tests
        // to exercise Plus-only navigation without touching StoreKit truth.
        if forcePlusForUITest { state = .plusActive }
#endif
    }

    deinit {
        updatesListener?.cancel()
    }

    /// Load products and current entitlements. Safe to call on launch.
    func load() async {
        isLoadingProducts = true
        productsLoadError = nil
        lastError = nil
        defer { isLoadingProducts = false }
        await loadProducts()
        await refreshEntitlements()
        startListening()
    }

    var monthlyProduct: Product? { products.first { $0.id == SubscriptionProductID.monthly } }
    var annualProduct: Product? { products.first { $0.id == SubscriptionProductID.annual } }

    /// True if the annual product offers a free trial.
    var annualHasFreeTrial: Bool {
        annualProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    // MARK: - Products

    private func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: SubscriptionProductID.all)
            guard !storeProducts.isEmpty else { throw ProductLoadError.noProducts }
            // Stable display order: annual first (best value), then monthly.
            products = storeProducts.sorted { $0.id == SubscriptionProductID.annual && $1.id != SubscriptionProductID.annual }
            productsLoadError = nil
        } catch {
            products = []
            productsLoadError = error.localizedDescription
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var highest: EntitlementState = .free
        var proof: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            guard SubscriptionProductID.all.contains(txn.productID) else { continue }
            let now = Date()
            let expires = txn.expirationDate ?? .distantFuture
            let previous = highest
            if txn.offerType == .introductory {
                if expires > now {
                    highest = EntitlementService.highest(highest, .plusTrial)
                }
            } else if expires > now {
                highest = EntitlementService.highest(highest, .plusActive)
            } else {
                highest = EntitlementService.highest(highest, .plusExpired)
            }
            // Keep the signature belonging to the entitlement we actually report.
            if highest != previous || proof == nil {
                proof = result.jwsRepresentation
            }
        }
        state = highest
        signedTransaction = proof
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    await txn.finish()
                    await refreshEntitlements()
                    if state.isPlus { return true }
                    lastError = L("paywall.purchase.error")
                    return false
                } else if case .unverified(_, let error) = verification {
                    lastError = error.localizedDescription
                }
                return false
            case .userCancelled:
                return false
            case .pending:
                lastError = L("paywall.purchase.pending")
                return false
            @unknown default:
                lastError = L("paywall.purchase.error")
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
            await refreshEntitlements()
            return false
        }
        await refreshEntitlements()
        return state.isPlus
    }

    // MARK: - Transaction listener

    private func startListening() {
        // `load()` runs on every paywall presentation; without this guard each
        // one would leak another `Transaction.updates` listener.
        guard updatesListener == nil else { return }
        updatesListener = Task { @MainActor [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                if case .verified(let txn) = result {
                    await txn.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private static func highest(_ a: EntitlementState, _ b: EntitlementState) -> EntitlementState {
        rank(b) > rank(a) ? b : a
    }

    private static func rank(_ state: EntitlementState) -> Int {
        switch state {
        case .free: return 0
        case .plusExpired: return 1
        case .plusGracePeriod: return 2
        case .plusTrial: return 3
        case .plusActive: return 4
        }
    }
}

private enum ProductLoadError: LocalizedError {
    case noProducts

    var errorDescription: String? {
        switch self {
        case .noProducts: return L("paywall.products.unavailable")
        }
    }
}
