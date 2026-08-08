import SwiftUI
import StoreKit

enum PaywallTrigger { case stepLimit, adminLimit, feature }

struct PaywallView: View {
    let trigger: PaywallTrigger
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = SubscriptionProductID.annual
    @State private var purchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing20) {
                    if trigger != .feature {
                        limitMessage
                    }

                    featuresList
                    planPicker

                    PrimaryButton(
                        ctaTitle,
                        enabled: selectedProduct != nil && !purchasing,
                        action: { purchase() }
                    )

                    Button(L("paywall.restore")) {
                        Task { await env.entitlement.restore() }
                    }
                    .font(.footnote)

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
            await env.entitlement.load()
            if env.entitlement.annualProduct != nil { selected = SubscriptionProductID.annual }
        }
    }

    private var limitMessage: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text(verbatim: L("paywall.limit.title"))
                .font(.headline)
            Text(verbatim: L("paywall.limit.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(verbatim: L("paywall.limit.keepFree"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .startKindCard()
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            featureRow("paywall.feature.unlimited")
            featureRow("paywall.feature.admin")
            featureRow("paywall.feature.calibration")
            featureRow("paywall.feature.recovery")
            featureRow("paywall.feature.costart")
            featureRow("paywall.feature.sync")
            featureRow("paywall.feature.model")
        }
    }

    private func featureRow(_ key: String) -> some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
            Text(verbatim: L(key)).font(.subheadline)
        }
    }

    private var planPicker: some View {
        VStack(spacing: Theme.spacing8) {
            planButton(id: SubscriptionProductID.annual)
            planButton(id: SubscriptionProductID.monthly)
        }
    }

    private func planButton(id: String) -> some View {
        let product = env.entitlement.products.first { $0.id == id }
        let isSelected = selected == id
        return Button {
            selected = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L(id == SubscriptionProductID.annual ? "paywall.annual" : "paywall.monthly"))
                        .fontWeight(.semibold)
                    if let product {
                        Text(verbatim: product.displayPrice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: id == SubscriptionProductID.annual ? L("paywall.annual.price") : L("paywall.monthly.price"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if id == SubscriptionProductID.annual {
                        Text(verbatim: L("paywall.annual.save"))
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Theme.accent)
            }
            .padding()
            .background(isSelected ? Theme.accent.opacity(0.12) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous)
                    .stroke(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedProduct: Product? {
        env.entitlement.products.first { $0.id == selected }
    }

    private var ctaTitle: String {
        (selected == SubscriptionProductID.annual && env.entitlement.annualHasFreeTrial)
            ? L("paywall.cta") : L("paywall.cta.buy")
    }

    private func purchase() {
        guard let product = selectedProduct else { return }
        purchasing = true
        Task {
            let success = await env.entitlement.purchase(product)
            purchasing = false
            if success {
                await env.syncEntitlementToBackend()
                dismiss()
            }
        }
    }
}
