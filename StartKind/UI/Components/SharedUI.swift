import SwiftUI

/// Large, high-contrast primary action button. Min 44pt tap target.
struct PrimaryButton: View {
    let label: Text
    let systemImage: String?
    let action: () -> Void
    var enabled: Bool = true
    /// Shows a spinner in place of the label. Work that takes a moment has to
    /// say so on the control that started it, or the tap reads as ignored.
    var busy: Bool = false
    var accessibilityId: String? = nil

    init(_ key: String, systemImage: String? = nil, enabled: Bool = true, busy: Bool = false, accessibilityId: String? = nil, action: @escaping () -> Void) {
        self.label = Text(verbatim: L(key))
        self.systemImage = systemImage
        self.enabled = enabled
        self.busy = busy
        self.accessibilityId = accessibilityId
        self.action = action
    }

    init(verbatim text: String, systemImage: String? = nil, enabled: Bool = true, busy: Bool = false, accessibilityId: String? = nil, action: @escaping () -> Void) {
        self.label = Text(verbatim: text)
        self.systemImage = systemImage
        self.enabled = enabled
        self.busy = busy
        self.accessibilityId = accessibilityId
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing8) {
                if busy {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                label.fontWeight(.semibold)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget + 4)
            .padding(.horizontal, Theme.spacing12)
            .foregroundStyle(.white)
            .background(enabled || busy ? Theme.accent : Color.secondary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
            .shadow(color: enabled ? Theme.accent.opacity(0.18) : .clear, radius: 8, x: 0, y: 4)
        }
        .pressableCard(dimsWhenDisabled: !busy)
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
        .pressableCard()
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

/// A quiet info banner for kind, non-punitive messages.
struct KindBanner: View {
    /// Something going wrong still has to read as "here is what happened",
    /// not as a reprimand - a red alarm is exactly the tone this app exists
    /// to avoid.
    enum Tone { case kind, warning }

    let text: String
    var tone: Tone = .kind

    private var foreground: Color {
        switch tone {
        case .kind: return Theme.accent
        case .warning: return Color.orange
        }
    }

    private var background: Color {
        switch tone {
        case .kind: return Theme.softAccent
        case .warning: return Theme.warmWash
        }
    }

    var body: some View {
        Text(verbatim: text)
            .font(.subheadline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacing12)
            .background(background)
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

/// Card-shaped buttons in this app draw their own background, so they use
/// `.plain` - which also throws away the press highlight. Without it a tap
/// produces no visible change at all, and the natural response is to tap
/// again. Give every one of them a press state of its own.
struct PressableCard: ButtonStyle {
    // A custom style opts out of the automatic dimming, so a disabled card
    // would otherwise look exactly like a live one - a tap target that
    // silently swallows taps is worse than no target at all.
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A control that is busy is disabled too, but it must stay legible: the
    /// spinner inside it is the whole point.
    var dimsWhenDisabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.975 : 1)
            .opacity(!isEnabled && dimsWhenDisabled ? 0.4 : (configuration.isPressed ? 0.68 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isEnabled)
            // Fires on the press, not the release, so the confirmation lands
            // under the finger at the moment of contact.
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                // Reduce Motion changes visual movement only; tactile feedback
                // remains useful and should not disappear for accessibility users.
                pressed
            }
    }
}

extension View {
    /// Replaces `.buttonStyle(.plain)` on anything that looks like a tappable card.
    func pressableCard(dimsWhenDisabled: Bool = true) -> some View {
        buttonStyle(PressableCard(dimsWhenDisabled: dimsWhenDisabled))
    }
}

/// Shown while a step is being generated. It is shaped like the card that is
/// about to replace it, so the wait reads as "your step is coming, here" -
/// not as an anonymous spinner somewhere on the page.
struct StepSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                ProgressView().tint(Theme.accent)
                Text(verbatim: L("capture.generating"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
            }
            bar(widthFraction: 0.72, height: 22)
            bar(widthFraction: 1.0, height: 14)
            bar(widthFraction: 0.86, height: 14)
        }
        .padding(Theme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius8, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
        .onAppear { pulsing = !reduceMotion }
        .onChange(of: reduceMotion) { _, value in
            pulsing = !value
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: L("capture.generating")))
        .accessibilityIdentifier("start.generating")
    }

    private func bar(widthFraction: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.softAccent)
                .frame(width: geo.size.width * widthFraction, height: height)
                .opacity(pulsing ? 0.45 : 0.95)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                    value: pulsing
                )
        }
        .frame(height: height)
    }
}
