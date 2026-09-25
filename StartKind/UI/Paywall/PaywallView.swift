import SwiftUI
import StoreKit

enum PaywallTrigger: Equatable {
    case stepLimit, adminLimit, friendCoStartLimit, feature

    /// Automatic presentation is reserved for an actual limit error returned
    /// by a feature operation. Settings uses `.feature` directly as its
    /// intentional subscription entry point.
    static func fromReturnedLimitError(_ error: Error) -> PaywallTrigger? {
        if let usageError = error as? UsageError {
            switch usageError {
            case .stepLimitReached: return .stepLimit
            case .adminLimitReached: return .adminLimit
            }
        }
        if let coStartError = error as? CoStartError,
           case .friendLimitReached = coStartError {
            return .friendCoStartLimit
        }
        return nil
    }
}

struct PaywallView: View {
    let trigger: PaywallTrigger
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selected: String = SubscriptionProductID.annual
    @State private var purchasing = false
    @State private var restoring = false
    @State private var purchaseFeedback: String?
    @State private var restoreFeedback: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing20) {
                    if trigger != .feature {
                        limitMessage
                    }

                    planPicker
                    productAction
                    contextLine
                    if let purchaseFeedback {
                        KindBanner(text: purchaseFeedback, tone: .warning)
                            .accessibilityIdentifier("paywall.purchase.error")
                    }
                    if let restoreFeedback {
                        KindBanner(
                            text: restoreFeedback,
                            tone: env.entitlement.lastError == nil ? .kind : .warning
                        )
                        .accessibilityIdentifier("paywall.restore.feedback")
                    }
                    Divider().background(Theme.line)
                    planComparison

                    Button {
                        guard !restoring else { return }
                        restoreFeedback = nil
                        restoring = true
                        Task {
                            let restored = await env.entitlement.restore()
                            if let error = env.entitlement.lastError {
                                restoreFeedback = error
                            } else if restored {
                                restoreFeedback = L("paywall.restore.success")
                            } else {
                                restoreFeedback = L("paywall.restore.none")
                            }
                            restoring = false
                        }
                    } label: {
                        HStack(spacing: Theme.spacing8) {
                            if restoring { ProgressView().controlSize(.small) }
                            Text(verbatim: L("paywall.restore"))
                        }
                    }
                    .font(.footnote)
                    .disabled(restoring)
                    .accessibilityIdentifier("paywall.restore")

                    legalLinks

                    Button(L("paywall.dismiss")) { dismiss() }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(L("paywall.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard !env.isUITestMode else { return }
            await env.entitlement.load()
        }
    }

    @ViewBuilder
    private var productAction: some View {
        if env.entitlement.isLoadingProducts {
            HStack(spacing: Theme.spacing8) {
                ProgressView()
                Text(verbatim: L("paywall.products.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)
            .accessibilityIdentifier("paywall.products.loading")
        } else if let error = env.entitlement.productsLoadError {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                KindBanner(text: error, tone: .warning)
                    .accessibilityIdentifier("paywall.products.error")
                QuietButton("paywall.products.retry", systemImage: "arrow.clockwise", accessibilityId: "paywall.products.retry") {
                    Task { await env.entitlement.load() }
                }
                .disabled(env.entitlement.isLoadingProducts)
            }
        } else if selectedProduct != nil {
            PrimaryButton(
                verbatim: ctaTitle,
                enabled: !purchasing,
                busy: purchasing,
                action: { purchase() }
            )
            .accessibilityIdentifier("paywall.subscribe")
        } else {
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                KindBanner(text: L("paywall.products.unavailable"), tone: .warning)
                    .accessibilityIdentifier("paywall.products.error")
                QuietButton("paywall.products.retry", systemImage: "arrow.clockwise", accessibilityId: "paywall.products.retry") {
                    Task { await env.entitlement.load() }
                }
            }
        }
    }

    private var limitMessage: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: limitTitle)
                .font(.headline)
            Text(verbatim: limitBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(verbatim: L("paywall.limit.keepFree"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .startKindCard()
    }

    private var contextLine: some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.accent)
            Text(verbatim: L("paywall.value.statement"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.spacing12)
        .padding(.vertical, Theme.spacing10)
        .background(Theme.softAccent.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var planComparison: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            SectionLabel("paywall.compare.title")
            comparisonCard(
                title: L("paywall.free.title"),
                price: L("paywall.free.price"),
                points: [
                    L("paywall.free.starts"),
                    L("paywall.free.admin"),
                    L("paywall.free.personal"),
                    L("paywall.free.sync")
                ],
                highlighted: false
            )
            comparisonCard(
                title: L("paywall.plus.title"),
                price: plusPrice,
                points: [
                    L("paywall.plus.starts"),
                    L("paywall.plus.admin"),
                    L("paywall.plus.recovery"),
                    L("paywall.plus.costart"),
                    L("paywall.plus.insights")
                ],
                highlighted: true
            )
        }
    }

    private func comparisonCard(title: String, price: String, points: [String], highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.headline)
                    Text(verbatim: price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(highlighted ? Theme.accent : .secondary)
                }
                Spacer()
                Image(systemName: highlighted ? "sparkles" : "checkmark.circle")
                    .foregroundStyle(highlighted ? Theme.accent : .secondary)
            }
            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: Theme.spacing8) {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(highlighted ? Theme.accent : .secondary)
                        .frame(width: 16)
                    Text(verbatim: point)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.spacing12)
        .background(highlighted ? Theme.softAccent : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(highlighted ? Theme.accent.opacity(0.28) : Theme.line, lineWidth: 1)
        )
    }

    private var planPicker: some View {
        VStack(spacing: Theme.spacing8) {
            planButton(id: SubscriptionProductID.annual)
            planButton(id: SubscriptionProductID.monthly)
        }
    }

    private func planButton(id: String) -> some View {
        let product = env.entitlement.products.first { $0.id == id }
        let isAvailable = product != nil
        let isSelected = isAvailable && selectedProduct?.id == id
        let isAnnual = id == SubscriptionProductID.annual
        return Button {
            guard isAvailable else { return }
            selected = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L(isAnnual ? "paywall.annual" : "paywall.monthly"))
                        .fontWeight(.semibold)
                        .foregroundStyle(isAvailable ? Theme.ink : .secondary)
                    if let product {
                        Text(verbatim: product.displayPrice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: L("paywall.products.priceUnavailable"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isAnnual, product != nil {
                        Text(verbatim: L("paywall.annual.bestValue"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(verbatim: L("paywall.annual.save"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.spacing8)
                            .padding(.vertical, Theme.spacing4)
                            .background(Theme.savingHighlight)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                            .accessibilityIdentifier("paywall.annual.save")
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isAvailable && isSelected ? Theme.accent : .secondary)
            }
            .padding()
            .background(isSelected ? Theme.softAccent : Theme.surfaceRaised.opacity(isAvailable ? 1 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.7) : Theme.line.opacity(isAvailable ? 1 : 0.55), lineWidth: 1)
            )
        }
        .pressableCard()
        .disabled(!isAvailable || purchasing)
        .opacity(isAvailable ? 1 : 0.55)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(Text(verbatim: product?.displayPrice ?? L("paywall.products.unavailable")))
        .accessibilityIdentifier(isAnnual ? "paywall.annual" : "paywall.monthly")
    }

    private var selectedProduct: Product? {
        env.entitlement.products.first { $0.id == selected }
            ?? env.entitlement.products.first
    }

    private var plusPrice: String {
        guard let monthly = env.entitlement.monthlyProduct,
              let annual = env.entitlement.annualProduct else {
            return L("paywall.products.priceUnavailable")
        }
        return L("paywall.plus.price", monthly.displayPrice, annual.displayPrice)
    }

    private var ctaTitle: String {
        (selectedProduct?.id == SubscriptionProductID.annual && env.entitlement.annualHasFreeTrial)
            ? L("paywall.cta") : L("paywall.cta.buy")
    }

    private func purchase() {
        guard let product = selectedProduct else {
            purchaseFeedback = L("paywall.products.unavailable")
            return
        }
        purchaseFeedback = nil
        purchasing = true
        Task {
            let success = await env.entitlement.purchase(product)
            purchasing = false
            if success {
                dismiss()
                Task { await env.syncEntitlementToBackend() }
            } else if let error = env.entitlement.lastError {
                purchaseFeedback = error
            } else {
                purchaseFeedback = L("paywall.purchase.notCompleted")
            }
        }
    }

    private var legalLinks: some View {
        HStack(spacing: Theme.spacing16) {
            Button {
                open(StartKindLegalLinks.privacy)
            } label: {
                Text(verbatim: L("legal.privacy"))
            }
            .accessibilityIdentifier("paywall.privacy")

            Button {
                open(StartKindLegalLinks.terms)
            } label: {
                Text(verbatim: L("legal.terms"))
            }
            .accessibilityIdentifier("paywall.terms")
        }
        .font(.footnote)
        .foregroundStyle(Theme.accent)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func open(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        openURL(url)
    }

    private var limitTitle: String {
        switch trigger {
        case .friendCoStartLimit:
            return L("paywall.limit.title.friend")
        case .adminLimit:
            return L("paywall.limit.title.admin")
        case .stepLimit:
            return L("paywall.limit.title")
        case .feature:
            return L("paywall.limit.title")
        }
    }

    private var limitBody: String {
        switch trigger {
        case .friendCoStartLimit:
            return L("paywall.limit.body.friend")
        case .adminLimit:
            return L("paywall.limit.body.admin")
        case .stepLimit:
            return L("paywall.limit.body")
        case .feature:
            return L("paywall.limit.body")
        }
    }
}
