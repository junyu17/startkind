import SwiftUI

/// Large, high-contrast primary action button. Min 44pt tap target.
struct PrimaryButton: View {
    let label: Text
    let systemImage: String?
    let action: () -> Void
    var enabled: Bool = true
    var accessibilityId: String? = nil

    init(_ key: String, systemImage: String? = nil, enabled: Bool = true, accessibilityId: String? = nil, action: @escaping () -> Void) {
        self.label = Text(verbatim: L(key))
        self.systemImage = systemImage
        self.enabled = enabled
        self.accessibilityId = accessibilityId
        self.action = action
    }

    init(verbatim text: String, systemImage: String? = nil, enabled: Bool = true, accessibilityId: String? = nil, action: @escaping () -> Void) {
        self.label = Text(verbatim: text)
        self.systemImage = systemImage
        self.enabled = enabled
        self.accessibilityId = accessibilityId
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing8) {
                if let systemImage { Image(systemName: systemImage) }
                label.fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.accent)
        .disabled(!enabled)
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

/// Secondary, quieter action button.
struct QuietButton: View {
    let label: String
    let systemImage: String?
    let action: () -> Void
    var accessibilityId: String? = nil

    init(_ key: String, systemImage: String? = nil, accessibilityId: String? = nil, action: @escaping () -> Void) {
        self.label = L(key)
        self.systemImage = systemImage
        self.accessibilityId = accessibilityId
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing4) {
                if let systemImage { Image(systemName: systemImage) }
                Text(verbatim: label)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

/// A quiet info banner for kind, non-punitive messages.
struct KindBanner: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.subheadline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacing12)
            .background(Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .accessibilityLabel(Text(verbatim: text))
    }
}

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
