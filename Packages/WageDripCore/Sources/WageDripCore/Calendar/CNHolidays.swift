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

extension CNHolidays {
    private static func storageKey(_ year: Int) -> String { "holidays.cn.\(year)" }
    private static let indexKey = "holidays.cn.years"

    /// Bundled data plus any newer year files downloaded earlier; downloaded files win.
    public static func cached(storage: KeyValueStoring) -> CNHolidays {
        let years = storage.data(forKey: indexKey).flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? []
        let downloaded = years.sorted().compactMap { storage.data(forKey: storageKey($0)) }
        return CNHolidays(jsonFiles: bundledData() + downloaded)
    }

    /// Saves a downloaded year file. Rejects anything that does not parse or has no entries,
    /// leaving existing data untouched.
    @discardableResult
    public static func storeDownloaded(_ data: Data, year: Int, storage: KeyValueStoring) -> Bool {
        guard let entries = parse(data), !entries.isEmpty else { return false }
        storage.setData(data, forKey: storageKey(year))
        var years = storage.data(forKey: indexKey).flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? []
        if !years.contains(year) { years.append(year) }
        storage.setData(try? JSONEncoder().encode(years), forKey: indexKey)
        return true
    }

    public static func downloadURL(year: Int) -> URL {
        URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!
    }
}

extension CNHolidays {
    /// The year files downloaded so far, keyed by year, for handing to another device.
    public static func downloadedFiles(storage: KeyValueStoring) -> [Int: Data] {
        let years = storage.data(forKey: indexKey).flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? []
        return Dictionary(years.compactMap { year in storage.data(forKey: storageKey(year)).map { (year, $0) } },
                          uniquingKeysWith: { _, new in new })
    }
}
