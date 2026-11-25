import Foundation

/// Mainland China public holidays and make-up workdays, read from holiday-cn year files
/// (https://github.com/NateScarlet/holiday-cn). Years without data yield no entries, so the
/// caller falls back to plain weekdays.
public struct CNHolidays: HolidayProvider {
    private let table: [DayKey: HolidayStatus]

    private struct YearFile: Decodable {
        struct Day: Decodable {
            let date: String
            let isOffDay: Bool
        }
        let days: [Day]
    }

    /// Unreadable files are skipped.
    public init(jsonFiles: [Data]) {
        var table: [DayKey: HolidayStatus] = [:]
        for data in jsonFiles {
            guard let entries = Self.parse(data) else { continue }
            table.merge(entries) { _, new in new }
        }
        self.table = table
    }

    public func status(for day: DayKey) -> HolidayStatus? { table[day] }

    public var isEmpty: Bool { table.isEmpty }

    static func parse(_ data: Data) -> [DayKey: HolidayStatus]? {
        guard let file = try? JSONDecoder().decode(YearFile.self, from: data) else { return nil }
        var result: [DayKey: HolidayStatus] = [:]
        for entry in file.days {
            guard let day = DayKey(string: entry.date) else { return nil }
            result[day] = entry.isOffDay ? .holiday : .makeupWorkday
        }
        return result
    }

    public static let bundledYears = [2026, 2027]

    static func bundledData() -> [Data] {
        bundledYears.compactMap { year in
            Bundle.module.url(forResource: "holidays-cn-\(year)", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        }
    }

    public static func bundled() -> CNHolidays {
        CNHolidays(jsonFiles: bundledData())
    }
}
