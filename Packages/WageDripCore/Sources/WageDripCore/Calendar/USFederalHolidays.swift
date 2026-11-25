import Foundation

/// The 11 US federal holidays, computed by rule, including observed-day shifts
/// (Saturday holidays are observed on Friday, Sunday holidays on Monday).
public struct USFederalHolidays: HolidayProvider {
    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    public init() {}

    public func status(for day: DayKey) -> HolidayStatus? {
        // New Year's Day of the following year can be observed on Dec 31 of this one.
        let days = Self.observedDays(year: day.year) + Self.observedDays(year: day.year + 1)
        return days.contains(day) ? .holiday : nil
    }

    static func observedDays(year: Int) -> [DayKey] {
        let fixed = [(1, 1), (6, 19), (7, 4), (11, 11), (12, 25)].map { observed(DayKey(year: year, month: $0.0, day: $0.1)) }
        let floating = [
            nthWeekday(2, ordinal: 3, month: 1, year: year),   // Martin Luther King Jr. Day
            nthWeekday(2, ordinal: 3, month: 2, year: year),   // Washington's Birthday
            lastWeekday(2, month: 5, year: year),              // Memorial Day
            nthWeekday(2, ordinal: 1, month: 9, year: year),   // Labor Day
            nthWeekday(2, ordinal: 2, month: 10, year: year),  // Columbus Day
            nthWeekday(5, ordinal: 4, month: 11, year: year),  // Thanksgiving
        ]
        return fixed + floating
    }

    private static func observed(_ day: DayKey) -> DayKey {
        switch day.weekday(in: gregorian) {
        case 7: day.adding(days: -1, calendar: gregorian)
        case 1: day.adding(days: 1, calendar: gregorian)
        default: day
        }
    }

    /// - Parameter weekday: 1 = Sunday ... 7 = Saturday.
    private static func nthWeekday(_ weekday: Int, ordinal: Int, month: Int, year: Int) -> DayKey {
        let first = DayKey(year: year, month: month, day: 1)
        let offset = (weekday - first.weekday(in: gregorian) + 7) % 7
        return DayKey(year: year, month: month, day: 1 + offset + (ordinal - 1) * 7)
    }

    private static func lastWeekday(_ weekday: Int, month: Int, year: Int) -> DayKey {
        let fifth = nthWeekday(weekday, ordinal: 5, month: month, year: year)
        let daysInMonth = gregorian.range(of: .day, in: .month, for: DayKey(year: year, month: month, day: 1).date(in: gregorian))?.count ?? 28
        return fifth.day <= daysInMonth ? fifth : nthWeekday(weekday, ordinal: 4, month: month, year: year)
    }
}
