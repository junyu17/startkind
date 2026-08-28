import SwiftUI
import StoreKit

enum PaywallTrigger { case stepLimit, adminLimit, friendCoStartLimit, feature }

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

                    planPicker
                    contextLine
                    PrimaryButton(
                        verbatim: ctaTitle,
                        enabled: selectedProduct != nil && !purchasing,
                        action: { purchase() }
                    )
                    .accessibilityIdentifier("paywall.subscribe")
                    Divider().background(Theme.line)
                    planComparison

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
                    L("paywall.free.stepLimit"),
                    L("paywall.free.adminLimit"),
                    L("paywall.free.recovery"),
                    L("paywall.free.costart")
                ],
                highlighted: false
            )
            comparisonCard(
                title: L("paywall.plus.title"),
                price: L("paywall.plus.price"),
                points: [
                    L("paywall.plus.unlimited"),
                    L("paywall.plus.admin"),
                    L("paywall.plus.calibration"),
                    L("paywall.plus.sync"),
                    L("paywall.plus.coStart")
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
        let isSelected = selected == id
        let isAnnual = id == SubscriptionProductID.annual
        return Button {
            selected = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L(isAnnual ? "paywall.annual" : "paywall.monthly"))
                        .fontWeight(.semibold)
                    if let product {
                        Text(verbatim: product.displayPrice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: isAnnual ? L("paywall.annual.price") : L("paywall.monthly.price"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isAnnual {
                        Text(verbatim: L("paywall.annual.monthlyEquivalent"))
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
                    .foregroundStyle(Theme.accent)
            }
            .padding()
            .background(isSelected ? Theme.softAccent : Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius12, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.7) : Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(isAnnual ? "paywall.annual" : "paywall.monthly")
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
