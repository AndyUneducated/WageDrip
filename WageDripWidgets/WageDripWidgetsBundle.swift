import SwiftUI
import WidgetKit
import WageDripCore

@main
struct WageDripWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

/// Stand-in until the real amount widgets land. Shows today's amount from the shared settings,
/// which also proves the extension can read the App Group.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlaceholderWidget", provider: PlaceholderProvider()) { entry in
            Text(entry.text)
                .font(.system(.title3, design: .monospaced))
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("窝囊费")
        .description("今天已赚")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now, text: "¥0.00")
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        let settings = AppGroup.loadSettings()
        let plan = TimelinePlanner.plan(from: .now, engine: AppGroup.makeEngine(settings: settings), calendar: .current)
        completion(Timeline(entries: plan.entryDates.map(entry(at:)), policy: .after(plan.reloadAfter)))
    }

    private func entry(at date: Date) -> PlaceholderEntry {
        let settings = AppGroup.loadSettings()
        let amount = AppGroup.converter(settings: settings)
            .display(AppGroup.makeEngine(settings: settings).snapshot(at: date).today)
        return PlaceholderEntry(date: date, text: MoneyFormatter.string(amount, currency: settings.displayCurrency, fractionDigits: 2))
    }
}
