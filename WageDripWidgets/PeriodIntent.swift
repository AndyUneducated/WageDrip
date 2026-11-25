import AppIntents
import WidgetKit
import WageDripCore

enum WidgetPeriod: String, AppEnum {
    case today, month, year

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "周期"
    static let caseDisplayRepresentations: [WidgetPeriod: DisplayRepresentation] = [
        .today: "今日", .month: "本月", .year: "今年",
    ]

    var period: Period {
        switch self {
        case .today: .today
        case .month: .month
        case .year: .year
        }
    }
}

/// Each single-value widget picks its own period, so "today" and "this month" can sit side by side.
struct PeriodIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "周期"
    static let description = IntentDescription("选择这个小组件显示哪个周期的金额。")

    @Parameter(title: "周期", default: .today)
    var period: WidgetPeriod
}
