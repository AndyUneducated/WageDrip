import Foundation

public struct PlannedNotification: Equatable, Sendable {
    /// "milestone.<uuid>.<yyyy-MM-dd>"
    public var id: String
    public var fireDate: Date
    public var milestone: Milestone
}

/// Works out, ahead of time, when upcoming milestones will be crossed. Earnings follow a known
/// curve, so these can be scheduled as local notifications without any background running.
public enum NotificationPlan {
    public static let limit = 60

    public static func plan(now: Date, horizonDays: Int = 7, milestones: [Milestone], thresholds: [UUID: Decimal],
                            evaluator: MilestoneEvaluator, calendar: Calendar) -> [PlannedNotification] {
        let today = DayKey(now, calendar: calendar)
        let horizonEnd = today.adding(days: horizonDays, calendar: calendar).date(in: calendar)
        var planned: [PlannedNotification] = []

        for milestone in milestones {
            guard let threshold = thresholds[milestone.id], threshold > 0 else { continue }
            switch milestone.period {
            case .today:
                for offset in 0..<horizonDays {
                    let day = today.adding(days: offset, calendar: calendar)
                    let after = offset == 0 ? now : day.date(in: calendar)
                    if let date = evaluator.crossingDate(threshold: threshold, period: .today, after: after) {
                        planned.append(.init(id: "milestone.\(milestone.id.uuidString).\(day.string)", fireDate: date, milestone: milestone))
                    }
                }
            case .month, .year:
                if let date = evaluator.crossingDate(threshold: threshold, period: milestone.period, after: now), date < horizonEnd {
                    let day = DayKey(date, calendar: calendar)
                    planned.append(.init(id: "milestone.\(milestone.id.uuidString).\(day.string)", fireDate: date, milestone: milestone))
                }
            }
        }
        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }
}
