import SwiftUI

@main
struct StartKindWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

/// Localized string for the watch bundle. The watch app ships its own
/// `Localizable.strings` because it cannot read the iOS app's bundle.
private func WL(_ key: String) -> String {
    NSLocalizedString(key, value: key, comment: "")
}

/// Builds an always-valid countdown range. `ClosedRange` traps when the upper
/// bound is in the past, which happens as soon as a start runs out.
enum WatchTimerRange {
    static func countdown(to endsAt: Date, from now: Date = .now) -> ClosedRange<Date> {
        min(now, endsAt)...endsAt
    }
}

struct WatchRootView: View {
    @State private var activeStart: WatchQuickStart = .emergency
    @State private var endsAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label("StartKind", systemImage: "arrow.up.forward")
                    .font(.headline)
                    .foregroundStyle(.green)

                if let endsAt {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: activeStart.title)
                            .font(.headline)
                        Text(verbatim: activeStart.step)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerInterval: WatchTimerRange.countdown(to: endsAt), countsDown: true)
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundStyle(.green)
                        Button(WL("watch.stop")) {
                            self.endsAt = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(WatchQuickStart.allCases) { start in
                        Button {
                            activeStart = start
                            endsAt = Date.now.addingTimeInterval(TimeInterval(start.minutes * 60))
                        } label: {
                            Label(start.title, systemImage: start.systemImage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

enum WatchQuickStart: String, CaseIterable, Identifiable {
    case emergency
    case startFive
    case stuck
    case rescue

    var id: String { rawValue }

    var title: String { WL("watch.\(rawValue).title") }

    var step: String { WL("watch.\(rawValue).step") }

    var minutes: Int {
        switch self {
        case .emergency, .rescue: return 3
        case .startFive, .stuck: return 5
        }
    }

    var systemImage: String {
        switch self {
        case .emergency: return "bolt.heart.fill"
        case .startFive: return "play.fill"
        case .stuck: return "lifepreserver"
        case .rescue: return "clock.arrow.circlepath"
        }
    }
}
