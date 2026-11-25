#if os(iOS)
import ActivityKit
import BackgroundTasks
import CryptoKit
import Foundation
import UIKit
import WageDripCore

/// Starts, updates and ends the Live Activity.
///
/// Without push, the amount can only be refreshed when the app gets to run: in the foreground, for
/// a few seconds after leaving it, and when the system grants a background refresh (roughly every
/// 7 to 9 minutes in testing). Starting needs the foreground, so upcoming workdays are scheduled
/// ahead of time whenever the app is open; the system then starts them on its own.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    static let refreshID = "com.andyuneducated.wagedrip.refresh"
    static let staleAfter: TimeInterval = 15 * 60
    /// How many upcoming workdays to schedule in advance. The system caps the number of
    /// activities per app (5 in testing, counting scheduled ones), so leave room for today's.
    static let scheduleAhead = 2

    /// Start and schedule requests must not interleave: two running at once exhaust the cap.
    private var queue: Task<Void, Never>?

    private func serialized(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = queue
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        queue = task
        await task.value
    }

    private typealias WageActivity = Activity<WageActivityAttributes>

    private var lastRefresh: Date?

    var isRunning: Bool {
        WageActivity.activities.contains { $0.activityState == .active || $0.activityState == .stale }
    }

    private func content(at date: Date, settings: Settings, engine: EarningsEngine) -> ActivityContent<LiveState> {
        let state = LiveState(at: date, settings: settings, engine: engine, converter: AppGroup.converter(settings: settings))
        return ActivityContent(state: state, staleDate: LiveState.staleDate(asOf: date, threshold: Self.staleAfter))
    }

    /// Brings everything up to date. Safe from the background: it only updates and ends.
    func refresh() async {
        // Several triggers can fire together (leaving the foreground, a settings change).
        if let last = lastRefresh, Date().timeIntervalSince(last) < 1 { return }
        lastRefresh = Date()
        let settings = AppGroup.loadSettings()
        let engine = AppGroup.makeEngine(settings: settings)
        let now = Date()
        let today = DayKey(now, calendar: .current)
        let content = content(at: now, settings: settings, engine: engine)
        guard await Self.apply(content, today: today) else { return }
        Diagnostics.record(content.state.isFinal ? "live end" : "live update")
    }

    /// - Returns: false if there was nothing showing.
    nonisolated private static func apply(_ content: ActivityContent<LiveState>, today: DayKey) async -> Bool {
        let live = WageActivity.activities.filter { $0.activityState == .active || $0.activityState == .stale }
        for activity in live {
            if activity.attributes.day != today {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else if content.state.isFinal {
                await activity.end(content, dismissalPolicy: .default)
            } else {
                await activity.update(content)
            }
        }
        return !live.isEmpty
    }

    /// Foreground only. Starts today's activity if pay is accruing, and schedules upcoming workdays.
    /// - Parameter manual: the user tapped the button, so start even if auto-start is off.
    func startIfAppropriate(manual: Bool) async {
        await serialized { await self.startNow(manual: manual) }
    }

    private func startNow(manual: Bool) async {
        let settings = AppGroup.loadSettings()
        guard manual || settings.autoStartLiveActivity else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Diagnostics.record("live not permitted")
            return
        }
        // The system sometimes launches the app in the background (after an install, for a widget
        // reload); starting is only possible, and only wanted, when the user has it open.
        guard UIApplication.shared.applicationState == .active else { return }
        let engine = AppGroup.makeEngine(settings: settings)
        let now = Date()
        if !isRunning, engine.perSecondRate(at: now) > 0 || (manual && engine.isPaidDay(DayKey(now, calendar: .current))) {
            do {
                _ = try WageActivity.request(attributes: .init(day: DayKey(now, calendar: .current)),
                                             content: content(at: now, settings: settings, engine: engine))
                Diagnostics.record("live start")
            } catch {
                Diagnostics.record("live start failed \(error.localizedDescription)")
            }
        }
        if settings.autoStartLiveActivity {
            await scheduleUpcoming(settings: settings, engine: engine, from: now)
        }
    }

    private static let signatureKey = "live.scheduleSignature"

    /// Makes sure the next few workdays have a scheduled start.
    ///
    /// Scheduling only works in the foreground, and replacing a schedule means cancelling the old
    /// one first, so this does nothing unless the app is active and the schedule is actually out of
    /// date. Otherwise a late call while the app is leaving the foreground would wipe the schedule
    /// and fail to recreate it.
    private func scheduleUpcoming(settings: Settings, engine: EarningsEngine, from now: Date) async {
        guard UIApplication.shared.applicationState == .active else { return }

        var starts: [Date] = []
        var cursor = now
        for _ in 0..<Self.scheduleAhead {
            guard let start = engine.nextWorkStart(after: cursor, calendar: .current) else { break }
            starts.append(start)
            cursor = start
        }
        let days = starts.map { DayKey($0, calendar: .current) }

        // Sign what would actually be scheduled: each day and the text it would show. (Hashing the
        // encoded settings does not work: sets and dictionaries encode in a different order each
        // time, so the signature never matched and the schedule was rebuilt on every call.)
        let contents = starts.map { content(at: $0, settings: settings, engine: engine) }
        var hasher = SHA256()
        for (day, content) in zip(days, contents) {
            let parts = [day.string, content.state.compactText] + content.state.lines.map { "\($0.period.rawValue)=\($0.text)" }
            hasher.update(data: Data(parts.joined(separator: "|").utf8))
        }
        let signature = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        if AppGroup.defaults.string(forKey: Self.signatureKey) == signature, Self.pendingDays() == Set(days) {
            return
        }

        await Self.endAll(in: [.pending])
        guard UIApplication.shared.applicationState == .active else {
            AppGroup.defaults.removeObject(forKey: Self.signatureKey)
            return
        }
        var scheduled = 0
        for (start, content) in zip(starts, contents) {
            do {
                _ = try WageActivity.request(
                    attributes: .init(day: DayKey(start, calendar: .current)),
                    content: content,
                    pushType: nil, style: .standard,
                    alertConfiguration: AlertConfiguration(title: "窝囊费", body: "开始计费", sound: .default),
                    start: start)
                scheduled += 1
            } catch {
                Diagnostics.record("live schedule failed \(error.localizedDescription)")
                break
            }
        }
        if scheduled == starts.count {
            AppGroup.defaults.set(signature, forKey: Self.signatureKey)
        } else {
            AppGroup.defaults.removeObject(forKey: Self.signatureKey)
        }
        Diagnostics.record("live scheduled \(scheduled)/\(starts.count)")
    }

    nonisolated private static func pendingDays() -> Set<DayKey> {
        Set(WageActivity.activities.filter { $0.activityState == .pending }.map(\.attributes.day))
    }

    func end() async {
        await Self.endAll(in: [.active, .stale])
        Diagnostics.record("live end manual")
    }

    /// Settings changed: refresh what is showing and redo the schedule, whose amounts depend on pay.
    func settingsChanged() async {
        await refresh()
        await serialized {
            let settings = AppGroup.loadSettings()
            if settings.autoStartLiveActivity {
                await self.scheduleUpcoming(settings: settings, engine: AppGroup.makeEngine(settings: settings), from: Date())
            } else {
                await Self.endAll(in: [.pending])
                AppGroup.defaults.removeObject(forKey: Self.signatureKey)
            }
        }
    }

    nonisolated private static func endAll(in states: Set<ActivityState>) async {
        for activity in WageActivity.activities where states.contains(activity.activityState) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshID)
        request.earliestBeginDate = Date().addingTimeInterval(5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Diagnostics.record("bg submit failed \(error.localizedDescription)")
        }
    }
}
#endif
