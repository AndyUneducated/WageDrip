import Foundation

public enum WorkStatus: Sendable, Equatable {
    case beforeWork, working, afterWork, flexEvening, restDay
}

/// Earnings at one instant. All amounts are gross, in the pay currency.
public struct EarningsSnapshot: Equatable, Sendable {
    public var today: Decimal
    public var month: Decimal
    public var year: Decimal
    /// What the whole day pays.
    public var dayTotal: Decimal
    public var status: WorkStatus
    /// Nil on rest days.
    public var workStart: Date?
    public var workEnd: Date?

    public func amount(for period: Period) -> Decimal {
        switch period {
        case .today: today
        case .month: month
        case .year: year
        }
    }
}

/// Turns settings and a workday calendar into earned amounts.
///
/// Monthly pay is spread over that month's actual workdays, so the month's running total lands
/// exactly on the monthly pay. Within a day, pay accrues along a piecewise-linear curve.
public struct EarningsEngine: Sendable {
    public let settings: Settings
    private let workdays: WorkdayCalendar
    private let calendar: Calendar

    private static let secondsPerDay = 86400

    public init(settings: Settings, workdays: WorkdayCalendar, calendar: Calendar) {
        self.settings = settings
        self.workdays = workdays
        self.calendar = calendar
    }

    /// Unused in hourly mode, where it is 0.
    public var monthlyGross: Decimal {
        switch settings.payMode {
        case .annual:
            let total = settings.annualBase
                + (settings.bonusEnabled ? settings.annualBonus : 0)
                + (settings.stockEnabled ? settings.annualStock : 0)
            return total / 12
        case .monthly: return settings.monthlyPay
        case .hourly: return 0
        }
    }

    private var startSeconds: Int { settings.workStart.secondsFromMidnight }
    private var endSeconds: Int { settings.workEnd.secondsFromMidnight }
    private var shiftSeconds: Int { max(endSeconds - startSeconds, 0) }
    private var usesFlex: Bool { settings.flexEnabled && settings.payMode != .hourly }

    /// A workday on or after the start date.
    public func isPaidDay(_ day: DayKey) -> Bool {
        if let start = settings.startDate, day < start { return false }
        return workdays.isWorkday(day)
    }

    public func dayWage(on day: DayKey) -> Decimal {
        guard isPaidDay(day) else { return 0 }
        return wage(paidDays: 1, inMonthOf: day)
    }

    /// Pay for `paidDays` paid days in the month of `day`. Multiplies before dividing so that a
    /// full month comes out to exactly the monthly pay.
    private func wage(paidDays: Int, inMonthOf day: DayKey) -> Decimal {
        guard paidDays > 0 else { return 0 }
        if settings.payMode == .hourly {
            return settings.hourlyPay * Decimal(shiftSeconds) / 3600 * Decimal(paidDays)
        }
        let total = workdays.workdays(inMonthOf: day).count
        guard total > 0 else { return 0 }
        return monthlyGross * Decimal(paidDays) / Decimal(total)
    }

    private func paidDayCount(inMonthOf day: DayKey, before limit: DayKey? = nil) -> Int {
        workdays.days(inMonthOf: day).filter { d in
            if let limit, !(d < limit) { return false }
            return isPaidDay(d)
        }.count
    }

    /// What the month pays in total, after trimming days before the start date.
    public func monthEntitlement(year: Int, month: Int) -> Decimal {
        let first = DayKey(year: year, month: month, day: 1)
        return wage(paidDays: paidDayCount(inMonthOf: first), inMonthOf: first)
    }

    /// Share of the day's pay earned by `date`, 0...1. Uses wall-clock time so that days with a
    /// daylight-saving shift still reach exactly 1 at the end of work.
    public func dayFraction(at date: Date) -> Decimal {
        let day = DayKey(date, calendar: calendar)
        guard isPaidDay(day) else { return 0 }
        return fraction(atSeconds: wallSeconds(of: date))
    }

    private func wallSeconds(of date: Date) -> Decimal {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let whole = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        // Millisecond resolution is plenty and keeps the arithmetic exact.
        let millis = (c.nanosecond ?? 0) / 1_000_000
        return Decimal(whole) + Decimal(millis) / 1000
    }

    private func fraction(atSeconds seconds: Decimal) -> Decimal {
        let start = Decimal(startSeconds), end = Decimal(endSeconds)
        guard shiftSeconds > 0 else { return seconds >= end ? 1 : 0 }
        let workShare = min(max((seconds - start) / (end - start), 0), 1)
        guard usesFlex else { return workShare }
        let weight = settings.flexWorkWeight
        if seconds < end { return weight * workShare }
        let evening = Decimal(Self.secondsPerDay) - end
        let eveningShare = evening > 0 ? min((seconds - end) / evening, 1) : 1
        return weight + (1 - weight) * eveningShare
    }

    /// Inverse of the day curve: the earliest wall-clock second at which `fraction` of the day's
    /// pay is earned. Nil if that fraction is never reached on the curve.
    public func secondsFromMidnight(forFraction fraction: Decimal) -> Decimal? {
        guard fraction >= 0, fraction <= 1, shiftSeconds > 0 else { return nil }
        let start = Decimal(startSeconds), end = Decimal(endSeconds)
        guard usesFlex else { return start + fraction * (end - start) }
        let weight = settings.flexWorkWeight
        if fraction <= weight, weight > 0 {
            return start + fraction / weight * (end - start)
        }
        guard weight < 1 else { return nil }
        return end + (fraction - weight) / (1 - weight) * (Decimal(Self.secondsPerDay) - end)
    }

    /// How fast pay is accruing right now, per second. Zero outside paid hours.
    public func perSecondRate(at date: Date) -> Decimal {
        let day = DayKey(date, calendar: calendar)
        let wage = dayWage(on: day)
        guard wage > 0, shiftSeconds > 0 else { return 0 }
        let seconds = wallSeconds(of: date)
        let start = Decimal(startSeconds), end = Decimal(endSeconds)
        if seconds < start { return 0 }
        if seconds < end {
            return wage * (usesFlex ? settings.flexWorkWeight : 1) / (end - start)
        }
        guard usesFlex else { return 0 }
        let evening = Decimal(Self.secondsPerDay) - end
        return evening > 0 ? wage * (1 - settings.flexWorkWeight) / evening : 0
    }

    public func snapshot(at date: Date) -> EarningsSnapshot {
        let day = DayKey(date, calendar: calendar)
        let paid = isPaidDay(day)
        let dayTotal = dayWage(on: day)
        let today = dayTotal * dayFraction(at: date)
        let month = wage(paidDays: paidDayCount(inMonthOf: day, before: day), inMonthOf: day) + today
        var year = month
        if day.month > 1 {
            for m in 1..<day.month {
                year += monthEntitlement(year: day.year, month: m)
            }
        }
        return EarningsSnapshot(
            today: today, month: month, year: year, dayTotal: dayTotal,
            status: status(paid: paid, seconds: wallSeconds(of: date)),
            workStart: paid ? wallClock(day, settings.workStart) : nil,
            workEnd: paid ? wallClock(day, settings.workEnd) : nil
        )
    }

    private func status(paid: Bool, seconds: Decimal) -> WorkStatus {
        guard paid else { return .restDay }
        if seconds < Decimal(startSeconds) { return .beforeWork }
        if seconds < Decimal(endSeconds) { return .working }
        return usesFlex ? .flexEvening : .afterWork
    }

    private func wallClock(_ day: DayKey, _ time: TimeOfDay) -> Date? {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                           hour: time.hour, minute: time.minute))
    }
}
