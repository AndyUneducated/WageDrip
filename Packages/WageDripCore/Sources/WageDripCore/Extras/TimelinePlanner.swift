import Foundation

public struct TimelinePlan: Equatable, Sendable {
    /// Ascending; the first entry is the planning start.
    public var entryDates: [Date]
    /// When to ask the system for a fresh timeline.
    public var reloadAfter: Date
}

/// Chooses the instants a widget timeline should have entries for: every `minuteStep` minutes
/// while pay is accruing, and only at state changes (work start, work end, midnight) otherwise.
public enum TimelinePlanner {
    public static func plan(from: Date, engine: EarningsEngine, calendar: Calendar,
                            minuteStep: Int = 1, maxEntries: Int = 240) -> TimelinePlan {
        let step = max(minuteStep, 1)
        let limit = max(maxEntries, 1)
        let day = DayKey(from, calendar: calendar)
        let midnight = day.adding(days: 1, calendar: calendar).date(in: calendar)

        func at(_ time: TimeOfDay) -> Date? {
            calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                               hour: time.hour, minute: time.minute))
        }
        let changes: [Date] = engine.isPaidDay(day)
            ? [at(engine.settings.workStart), at(engine.settings.workEnd)].compactMap { $0 } + [midnight]
            : [midnight]

        var entries = [from]
        var current = from
        while entries.count < limit, current < midnight {
            let nextChange = changes.first { $0 > current } ?? midnight
            var next = nextChange
            if engine.perSecondRate(at: current) > 0 {
                let minuteStart = calendar.dateInterval(of: .minute, for: current)?.start ?? current
                let tick = minuteStart.addingTimeInterval(TimeInterval(step * 60))
                next = min(tick, nextChange)
            }
            next = min(next, midnight)
            entries.append(next)
            current = next
        }
        return TimelinePlan(entryDates: entries, reloadAfter: entries.last ?? from)
    }
}
