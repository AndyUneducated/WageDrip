import Foundation

/// A named amount within a period ("lunch", "rent") that the user's earnings cross.
public struct Milestone: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var nameKey: String?
    public var customName: String?
    public var amount: Decimal
    public var currency: String
    public var period: Period

    public init(id: UUID = UUID(), nameKey: String? = nil, customName: String? = nil,
                amount: Decimal, currency: String, period: Period) {
        self.id = id
        self.nameKey = nameKey
        self.customName = customName
        self.amount = amount
        self.currency = currency
        self.period = period
    }

    public static func defaults(for region: Region) -> [Milestone] {
        let items: [(String, Decimal, Period)]
        switch region {
        case .cn:
            items = [("milestone.lunch", 30, .today), ("milestone.commute", 10, .today),
                     ("milestone.rent", 5000, .month),
                     ("milestone.first10k", 10000, .year), ("milestone.first100k", 100000, .year)]
        case .us:
            items = [("milestone.lunch", 15, .today), ("milestone.commute", 6, .today),
                     ("milestone.rent", 2000, .month),
                     ("milestone.first10k", 10000, .year), ("milestone.first100k", 100000, .year)]
        }
        return items.enumerated().map { index, item in
            Milestone(id: stableID(region: region, kind: 2, index: index), nameKey: item.0,
                      amount: item.1, currency: region.defaultCurrency, period: item.2)
        }
    }
}

/// Works out which milestones are reached and when the next ones will be.
public struct MilestoneEvaluator: Sendable {
    private let engine: EarningsEngine
    private let converter: DisplayConverter
    private let calendar: Calendar

    public init(engine: EarningsEngine, converter: DisplayConverter, calendar: Calendar) {
        self.engine = engine
        self.converter = converter
        self.calendar = calendar
    }

    /// Milestones whose threshold (already in display currency) is met at `date`.
    public func reached(_ milestones: [Milestone], at date: Date, thresholds: [UUID: Decimal]) -> [Milestone] {
        let snapshot = engine.snapshot(at: date)
        return milestones.filter { m in
            guard let threshold = thresholds[m.id] else { return false }
            return converter.display(snapshot.amount(for: m.period)) >= threshold
        }
    }

    /// The moment the displayed amount for `period` first reaches `threshold`, strictly after `date`
    /// and within the period `date` falls in. Nil if already reached or unreachable in this period.
    public func crossingDate(threshold: Decimal, period: Period, after date: Date) -> Date? {
        let factor = converter.display(1)
        guard factor > 0, threshold > 0 else { return nil }
        let target = threshold / factor
        guard engine.snapshot(at: date).amount(for: period) < target else { return nil }

        let first = DayKey(date, calendar: calendar)
        var day = first
        while isSamePeriod(day, first, period) {
            let dayStart = day.date(in: calendar)
            let before = engine.snapshot(at: dayStart).amount(for: period)
            let wage = engine.dayWage(on: day)
            if wage > 0, before + wage >= target {
                let fraction = (target - before) / wage
                if let seconds = engine.secondsFromMidnight(forFraction: fraction) {
                    let whole = NSDecimalNumber(decimal: seconds).doubleValue.rounded(.up)
                    if let moment = wallClock(day: day, seconds: Int(whole)), moment > date {
                        return moment
                    }
                }
            }
            day = day.adding(days: 1, calendar: calendar)
        }
        return nil
    }

    private func isSamePeriod(_ a: DayKey, _ b: DayKey, _ period: Period) -> Bool {
        switch period {
        case .today: a == b
        case .month: a.year == b.year && a.month == b.month
        case .year: a.year == b.year
        }
    }

    private func wallClock(day: DayKey, seconds: Int) -> Date? {
        if seconds >= 86400 {
            return day.adding(days: 1, calendar: calendar).date(in: calendar)
        }
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                  hour: seconds / 3600, minute: (seconds % 3600) / 60,
                                                  second: seconds % 60))
    }
}
