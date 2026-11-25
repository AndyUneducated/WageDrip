import Foundation

extension Region {
    public var defaultCurrency: String {
        switch self {
        case .cn: "CNY"
        case .us: "USD"
        }
    }

    public var defaultHolidayCalendar: HolidayCalendarKind {
        switch self {
        case .cn: .cn
        case .us: .us
        }
    }

    public var defaultWorkStart: TimeOfDay { TimeOfDay(hour: 9, minute: 0) }

    public var defaultWorkEnd: TimeOfDay {
        switch self {
        case .cn: TimeOfDay(hour: 18, minute: 0)
        case .us: TimeOfDay(hour: 17, minute: 0)
        }
    }
}

public let supportedCurrencies: [String] = ["CNY", "USD", "EUR", "GBP", "JPY", "HKD", "CAD", "AUD", "SGD"]
