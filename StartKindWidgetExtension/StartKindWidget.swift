import WidgetKit
import SwiftUI

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

@main
struct StartKindWidgetBundle: WidgetBundle {
    var body: some Widget {
        StartKindWidget()
    }
}
