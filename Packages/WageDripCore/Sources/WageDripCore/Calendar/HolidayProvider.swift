import Foundation

public enum HolidayStatus: Sendable, Equatable {
    /// A public holiday: no work even on a weekday.
    case holiday
    /// A make-up workday: work even though it is a weekend.
    case makeupWorkday
}

public protocol HolidayProvider: Sendable {
    func status(for day: DayKey) -> HolidayStatus?
}

public struct NoHolidays: HolidayProvider {
    public init() {}
    public func status(for day: DayKey) -> HolidayStatus? { nil }
}

/// - Parameter cnData: holiday-cn year files to use for China; nil uses the bundled ones.
public func makeHolidayProvider(_ kind: HolidayCalendarKind, cnData: [Data]? = nil) -> HolidayProvider {
    switch kind {
    case .cn: cnData.map { CNHolidays(jsonFiles: $0) } ?? CNHolidays.bundled()
    case .us: USFederalHolidays()
    case .none: NoHolidays()
    }
}
