#if os(iOS)
import ActivityKit
import BackgroundTasks
import Foundation
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

    var isRunning: Bool {
        WageActivity.activities.contains { $0.activityState == .active || $0.activityState == .stale }
    }

    private func content(at date: Date, settings: Settings, engine: EarningsEngine) -> ActivityContent<LiveState> {
        let state = LiveState(at: date, settings: settings, engine: engine, converter: AppGroup.converter(settings: settings))
        return ActivityContent(state: state, staleDate: LiveState.staleDate(asOf: date, threshold: Self.staleAfter))
    }

    /// Brings everything up to date. Safe from the background: it only updates and ends.
    func refresh() async {
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

    /// Replaces all scheduled starts with fresh ones for the next few workdays.
    private func scheduleUpcoming(settings: Settings, engine: EarningsEngine, from now: Date) async {
        await Self.endAll(in: [.pending])
        var cursor = now
        var scheduled = 0
        for _ in 0..<Self.scheduleAhead {
            guard let start = engine.nextWorkStart(after: cursor, calendar: .current) else { break }
            cursor = start
            do {
                _ = try WageActivity.request(
                    attributes: .init(day: DayKey(start, calendar: .current)),
                    content: content(at: start, settings: settings, engine: engine),
                    pushType: nil, style: .standard,
                    alertConfiguration: AlertConfiguration(title: "窝囊费", body: "开始计费", sound: .default),
                    start: start)
                scheduled += 1
            } catch {
                Diagnostics.record("live schedule failed \(error.localizedDescription)")
                break
            }
        }
        Diagnostics.record("live scheduled \(scheduled)")
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
