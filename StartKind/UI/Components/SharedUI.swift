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
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)
            .padding(.horizontal, Theme.spacing12)
            .foregroundStyle(.white)
            .background(enabled ? Theme.accent : Color.secondary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .shadow(color: enabled ? Theme.accent.opacity(0.18) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            .padding(.horizontal, Theme.spacing12)
            .foregroundStyle(Theme.ink)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            .background(Theme.softAccent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                    .stroke(Theme.accent.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel(Text(verbatim: text))
    }
}

struct FieldShell<Content: View>: View {
    let systemImage: String?
    @ViewBuilder let content: Content

    init(systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        HStack(spacing: Theme.spacing10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
            }
            content
        }
        .padding(.horizontal, Theme.spacing12)
        .frame(minHeight: Theme.minTapTarget + 8)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

struct SectionLabel: View {
    let text: String

    init(_ key: String) {
        text = L(key)
    }

    init(verbatim text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
