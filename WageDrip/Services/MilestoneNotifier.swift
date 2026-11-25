import Foundation
import UserNotifications
import WageDripCore

/// Schedules local notifications for the moments upcoming milestones will be crossed.
@MainActor
enum MilestoneNotifier {
    private static let prefix = "milestone."

    /// Asks for permission. Returns false if the user has declined.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Clears and rebuilds all milestone notifications from the current settings.
    static func reschedule(settings: Settings, rate: Decimal) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard settings.milestoneAlertsEnabled else { return }

        let calendar = Calendar.current
        let evaluator = MilestoneEvaluator(engine: AppGroup.makeEngine(settings: settings),
                                           converter: DisplayConverter(settings: settings, rate: rate), calendar: calendar)
        let planned = NotificationPlan.plan(now: Date(), milestones: settings.milestones,
                                            thresholds: settings.milestoneThresholds(payToDisplayRate: rate),
                                            evaluator: evaluator, calendar: calendar)
        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "窝囊费")
            content.body = String(localized: "已赚回：\(item.milestone.displayName)")
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}
