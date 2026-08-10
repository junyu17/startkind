import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

struct StartKindWidgetEntry: TimelineEntry {
    let date: Date
}

struct StartKindWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartKindWidgetEntry {
        StartKindWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (StartKindWidgetEntry) -> Void) {
        completion(StartKindWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartKindWidgetEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
        completion(Timeline(entries: [StartKindWidgetEntry(date: .now)], policy: .after(next)))
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
            Text("StartKind")
                .font(.headline)
                .fontWeight(.bold)
            Text(family == .systemSmall ? "One kind step." : "Open StartKind and start with one small step.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "startkind://start"))
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
