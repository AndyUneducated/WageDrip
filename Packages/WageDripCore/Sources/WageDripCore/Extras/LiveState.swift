import Foundation

/// What the Live Activity shows. Amounts are pre-formatted because the Live Activity cannot
/// compute anything itself between updates.
public struct LiveState: Codable, Hashable, Sendable {
    public struct Line: Codable, Hashable, Sendable {
        public var period: Period
        public var text: String
    }

    /// Selected periods in priority order; the first is the most prominent.
    public var lines: [Line]
    /// Always today's amount: the Dynamic Island's compact slot has room for one number.
    public var compactText: String
    /// When these amounts were computed.
    public var asOf: Date
    /// End of work, only while working fixed hours.
    public var countdownEnd: Date?
    /// The day is settled: work has ended and the amounts will not change again today.
    public var isFinal: Bool

    public init(at date: Date, settings: Settings, engine: EarningsEngine, converter: DisplayConverter) {
        let snapshot = engine.snapshot(at: date)
        func text(_ period: Period) -> String {
            MoneyFormatter.string(converter.display(snapshot.amount(for: period)),
                                  currency: settings.displayCurrency, fractionDigits: 2)
        }
        let periods = (settings.periods.isEmpty ? [.today] : settings.periods).sorted()
        lines = periods.map { Line(period: $0, text: text($0)) }
        compactText = text(.today)
        asOf = date
        let fixedHours = !(settings.flexEnabled && settings.payMode != .hourly)
        countdownEnd = snapshot.status == .working && fixedHours ? snapshot.workEnd : nil
        isFinal = snapshot.status == .afterWork
    }

    public static func staleDate(asOf: Date, threshold: TimeInterval) -> Date {
        asOf.addingTimeInterval(threshold)
    }
}

extension EarningsEngine {
    /// The next moment pay starts accruing, strictly after `date`, looking up to two weeks ahead.
    public func nextWorkStart(after date: Date, calendar: Calendar) -> Date? {
        var day = DayKey(date, calendar: calendar)
        for _ in 0..<15 {
            if isPaidDay(day),
               let start = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                              hour: settings.workStart.hour, minute: settings.workStart.minute)),
               start > date {
                return start
            }
            day = day.adding(days: 1, calendar: calendar)
        }
        return nil
    }
}
