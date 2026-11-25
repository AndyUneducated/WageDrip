import Foundation
@testable import WageDripCore

func makeCalendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

let shanghai = makeCalendar("Asia/Shanghai")
let losAngeles = makeCalendar("America/Los_Angeles")

func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0, in calendar: Calendar = shanghai) -> Date {
    calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
}

func dec(_ s: String) -> Decimal { Decimal(string: s)! }

func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

/// China defaults, monthly pay 30000, 9:00 to 18:00.
func cnSettings(_ edit: (inout Settings) -> Void = { _ in }) -> Settings {
    var s = Settings.defaults(for: .cn)
    s.monthlyPay = 30000
    edit(&s)
    return s
}

func makeEngine(_ settings: Settings, calendar: Calendar = shanghai) -> EarningsEngine {
    let workdays = WorkdayCalendar(provider: makeHolidayProvider(settings.holidayCalendar),
                                   overrides: settings.dayOverrides, calendar: calendar)
    return EarningsEngine(settings: settings, workdays: workdays, calendar: calendar)
}

final class MemoryStore: KeyValueStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        lock.withLock { values[key] }
    }

    func setData(_ data: Data?, forKey key: String) {
        lock.withLock { values[key] = data }
    }
}
