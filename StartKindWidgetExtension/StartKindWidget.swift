import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

struct StartKindWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: StartKindWidgetSnapshot?
}

struct StartKindWidgetSnapshot: Codable, Equatable {
    var title: String
    var step: String
    var deepLinkString: String
}

struct StartKindWidgetSnapshotStore {
    static func load() -> StartKindWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: "group.ren.startkind") ?? .standard
        guard let data = defaults.data(forKey: "sk_widget_next_step") else { return nil }
        return try? JSONDecoder().decode(StartKindWidgetSnapshot.self, from: data)
    }
}

struct StartKindWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartKindWidgetEntry {
        StartKindWidgetEntry(
            date: .now,
            snapshot: StartKindWidgetSnapshot(
                title: "StartKind",
                step: "One kind step.",
                deepLinkString: "startkind://start"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StartKindWidgetEntry) -> Void) {
        completion(StartKindWidgetEntry(date: .now, snapshot: StartKindWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartKindWidgetEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
        completion(Timeline(entries: [StartKindWidgetEntry(date: .now, snapshot: StartKindWidgetSnapshotStore.load())], policy: .after(next)))
    }
}

struct StartKindWidgetView: View {
    let entry: StartKindWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.forward")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0.11, green: 0.45, blue: 0.29))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Spacer()
            }
            Spacer(minLength: 4)
            Text(entry.snapshot?.title ?? "StartKind")
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(2)
            Text(widgetStepText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(family == .systemSmall ? 3 : 4)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: entry.snapshot?.deepLinkString ?? "startkind://start"))
    }
}

extension StartKindWidgetView {
    private var widgetStepText: String {
        entry.snapshot?.step ?? (family == .systemSmall ? "One kind step." : "Open StartKind and start with one small step.")
    }
}

struct StartKindWidget: Widget {
    let kind = "StartKindWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StartKindWidgetProvider()) { entry in
            StartKindWidgetView(entry: entry)
        }
        .configurationDisplayName("StartKind")
        .description("Start one kind step from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOSApplicationExtension 16.2, *)
struct StartKindTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StartKindTimerAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.state.step)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.11, green: 0.45, blue: 0.29))
            }
            .padding(12)
            .activityBackgroundTint(.white)
            .activitySystemActionForegroundColor(Color(red: 0.11, green: 0.45, blue: 0.29))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("StartKind")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                        .font(.caption2)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.step)
                        .font(.caption)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: "arrow.up.forward")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "play.fill")
            }
            .widgetURL(URL(string: "startkind://start"))
        }
        .configurationDisplayName("StartKind Timer")
        .description("Keep one small step visible while the timer runs.")
    }
}

@main
struct StartKindWidgetBundle: WidgetBundle {
    var body: some Widget {
        StartKindWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            StartKindTimerLiveActivity()
        }
    }
}
