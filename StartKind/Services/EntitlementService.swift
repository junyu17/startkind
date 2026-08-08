import Foundation
import StoreKit

/// StoreKit 2 entitlement management.
///
/// Treats the App Store as the source of truth for entitlements. Plus cloud
/// features mirror this state to Supabase (see SyncService). Never hardcodes
/// shared secrets; only uses official StoreKit flows.
@MainActor
final class EntitlementService: ObservableObject {
    @Published private(set) var state: EntitlementState = .free
    @Published private(set) var products: [Product] = []
    @Published var lastError: String?

    private var updatesListener: Task<Void, Never>?

    init() {}

    deinit {
        updatesListener?.cancel()
    }

    /// Load products and current entitlements. Safe to call on launch.
    func load() async {
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
            // Stable display order: annual first (best value), then monthly.
            products = storeProducts.sorted { $0.id == SubscriptionProductID.annual && $1.id != SubscriptionProductID.annual }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var highest: EntitlementState = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            guard SubscriptionProductID.all.contains(txn.productID) else { continue }
            let now = Date()
            let expires = txn.expirationDate ?? .distantFuture
            if txn.offerType == .introductory {
                if expires > now {
                    highest = EntitlementService.highest(highest, .plusTrial)
                }
            } else if expires > now {
                highest = EntitlementService.highest(highest, .plusActive)
            } else {
                highest = EntitlementService.highest(highest, .plusExpired)
            }
        }
        state = highest
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
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - Transaction listener

    private func startListening() {
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
