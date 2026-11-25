import SwiftUI
import WidgetKit
import WageDripCore

struct AmountEntry: TimelineEntry {
    let date: Date
    /// The period this widget instance is configured for.
    let period: Period
    let amounts: [Period: Decimal]
    /// Globally selected periods, in priority order, for the medium widget.
    let selected: [Period]
    let currency: String
    let equivalent: String?

    func text(_ period: Period) -> String {
        MoneyFormatter.string(amounts[period] ?? 0, currency: currency, fractionDigits: 2)
    }

    /// For the tiny circular slot: 742, 1.2k, 14k.
    var shortText: String {
        let value = NSDecimalNumber(decimal: amounts[period] ?? 0).doubleValue
        switch value {
        case ..<1000: return String(Int(value))
        case ..<10000: return String(format: "%.1fk", (value / 100).rounded(.down) / 10)
        case ..<1_000_000: return "\(Int(value / 1000))k"
        default: return String(format: "%.1fM", (value / 100_000).rounded(.down) / 10)
        }
    }
}

struct AmountProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AmountEntry {
        AmountEntry(date: .now, period: .today, amounts: [.today: 742.31, .month: 14105.52, .year: 268340.17],
                    selected: Period.allCases, currency: "CNY", equivalent: nil)
    }

    func snapshot(for configuration: PeriodIntent, in context: Context) async -> AmountEntry {
        context.isPreview ? placeholder(in: context) : makeEntries(for: configuration, dates: [.now])[0]
    }

    func timeline(for configuration: PeriodIntent, in context: Context) async -> Timeline<AmountEntry> {
        Diagnostics.record("widget reload \(context.family)")
        let settings = AppGroup.loadSettings()
        let plan = TimelinePlanner.plan(from: .now, engine: AppGroup.makeEngine(settings: settings), calendar: .current)
        return Timeline(entries: makeEntries(for: configuration, dates: plan.entryDates), policy: .after(plan.reloadAfter))
    }

    private func makeEntries(for configuration: PeriodIntent, dates: [Date]) -> [AmountEntry] {
        let settings = AppGroup.loadSettings()
        let engine = AppGroup.makeEngine(settings: settings)
        let rate = AppGroup.cachedRate(settings: settings).rate
        let converter = DisplayConverter(settings: settings, rate: rate)
        return dates.map { date in
            let model = ReceiptModel(at: date, settings: settings, engine: engine, converter: converter, payToDisplayRate: rate)
            let snapshot = engine.snapshot(at: date)
            let amounts = Dictionary(uniqueKeysWithValues: Period.allCases.map { ($0, converter.display(snapshot.amount(for: $0))) })
            let equivalent = model.equivalent.map { line in
                let parts = MoneyFormatter.parts(line.count, fractionDigits: 1)
                return "\(line.item.displayName) × \(parts.integer).\(parts.fraction)"
            }
            return AmountEntry(date: date, period: configuration.period.period, amounts: amounts,
                               selected: [model.headline.period] + model.otherLines.map(\.period),
                               currency: settings.displayCurrency, equivalent: equivalent)
        }
    }
}

struct AmountWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AmountWidget", intent: PeriodIntent.self, provider: AmountProvider()) { entry in
            AmountWidgetView(entry: entry)
        }
        .configurationDisplayName("窝囊费")
        .description("显示今天、本月或今年已赚到的钱。")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct AmountWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AmountEntry

    var body: some View {
        switch family {
        case .systemMedium:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(entry.selected.enumerated()), id: \.element) { index, period in
                    HStack(alignment: .firstTextBaseline) {
                        Text(period.label)
                            .foregroundStyle(ReceiptTheme.inkSecondary)
                        Spacer()
                        Text(verbatim: entry.text(period))
                            .font(ReceiptTheme.font(index == 0 ? .title2 : .callout, weight: index == 0 ? .medium : .regular))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .font(ReceiptTheme.font(.callout))
                }
                if let equivalent = entry.equivalent {
                    DashedDivider()
                    Text(verbatim: equivalent)
                        .font(ReceiptTheme.font(.footnote))
                        .foregroundStyle(ReceiptTheme.inkSecondary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(ReceiptTheme.ink)
            .containerBackground(ReceiptTheme.paper, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.period.headlineLabel)
                    .font(.system(.caption, design: .monospaced))
                Text(verbatim: entry.text(entry.period))
                    .font(.system(.title3, design: .monospaced, weight: .medium))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            HStack(spacing: 4) {
                Text(entry.period.label)
                Text(verbatim: entry.text(entry.period))
            }
            .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "drop.fill").font(.caption2)
                Text(verbatim: entry.shortText)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .containerBackground(.clear, for: .widget)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("窝 囊 费")
                    .font(ReceiptTheme.font(.caption))
                    .frame(maxWidth: .infinity)
                DashedDivider()
                Text(entry.period.headlineLabel)
                    .font(ReceiptTheme.font(.caption))
                    .foregroundStyle(ReceiptTheme.inkSecondary)
                Text(verbatim: entry.text(entry.period))
                    .font(ReceiptTheme.font(.title2, weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(ReceiptTheme.ink)
            .containerBackground(ReceiptTheme.paper, for: .widget)
        }
    }
}
