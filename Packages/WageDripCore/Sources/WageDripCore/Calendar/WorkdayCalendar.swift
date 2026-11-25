import Foundation

/// Decides whether a day is a workday: manual override first, then the holiday calendar,
/// then Monday to Friday.
public struct WorkdayCalendar: Sendable {
    private let provider: HolidayProvider
    private let overrides: [DayKey: DayOverride]
    private let calendar: Calendar

    public init(provider: HolidayProvider, overrides: [DayKey: DayOverride], calendar: Calendar) {
        self.provider = provider
        self.overrides = overrides
        self.calendar = calendar
    }

    public func isWorkday(_ day: DayKey) -> Bool {
        if let override = overrides[day] {
            return override == .work
        }
        switch provider.status(for: day) {
        case .holiday: return false
        case .makeupWorkday: return true
        case nil:
            let weekday = day.weekday(in: calendar)
            return weekday != 1 && weekday != 7
        }
    }

    public func days(inMonthOf day: DayKey) -> [DayKey] {
        let first = DayKey(year: day.year, month: day.month, day: 1)
        let count = calendar.range(of: .day, in: .month, for: first.date(in: calendar))?.count ?? 0
        return (0..<count).map { DayKey(year: day.year, month: day.month, day: $0 + 1) }
    }

    public func workdays(inMonthOf day: DayKey) -> [DayKey] {
        days(inMonthOf: day).filter(isWorkday)
    }
}
