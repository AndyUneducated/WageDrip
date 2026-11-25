import Foundation
import Observation
import WidgetKit
import WageDripCore

/// The single source of truth for user settings in the app. Every change is validated, written
/// to the App Group, and pushed out to widgets and any other listeners.
@Observable @MainActor
final class SettingsStore {
    private var stored: Settings
    /// The pay-to-display exchange rate currently in use.
    private(set) var rate: RateResult
    @ObservationIgnored private var engineCache: (settings: Settings, engine: EarningsEngine)?
    @ObservationIgnored private let rates = ExchangeRateStore(fetcher: FrankfurterFetcher(), storage: AppGroup.defaults)

    var settings: Settings {
        get { stored }
        set {
            let valid = newValue.validated()
            guard valid != stored else { return }
            stored = valid
            rate = rates.cachedRate(for: valid)
            AppGroup.save(valid)
            WidgetCenter.shared.reloadAllTimelines()
            scheduleFollowUps()
        }
    }

    @ObservationIgnored private var followUp: Task<Void, Never>?

    /// Things that depend on settings but are too heavy to redo on every keystroke: notification
    /// schedules and the Live Activity. Coalesced with a short delay.
    private func scheduleFollowUps() {
        followUp?.cancel()
        followUp = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            await MilestoneNotifier.reschedule(settings: self.stored, rate: self.rate.rate)
            #if os(iOS)
            await LiveActivityController.shared.settingsChanged()
            #endif
        }
    }

    init() {
        let loaded = AppGroup.loadSettings()
        stored = loaded
        rate = ExchangeRateStore.cachedRate(for: loaded, storage: AppGroup.defaults)
    }

    /// The engine is rebuilt only when settings change, not on every frame.
    var engine: EarningsEngine {
        if let cached = engineCache, cached.settings == stored { return cached.engine }
        let engine = AppGroup.makeEngine(settings: stored)
        engineCache = (stored, engine)
        return engine
    }

    var converter: DisplayConverter {
        DisplayConverter(settings: stored, rate: rate.rate)
    }

    func receipt(at date: Date) -> ReceiptModel {
        ReceiptModel(at: date, settings: stored, engine: engine, converter: converter, payToDisplayRate: rate.rate)
    }

    /// Everything that should happen when the app comes to the foreground.
    func appBecameActive() async {
        await refreshRate()
        if await DataRefresher.refreshHolidaysIfDue() {
            engineCache = nil
            WidgetCenter.shared.reloadAllTimelines()
        }
        guard stored.onboardingDone else { return }
        await MilestoneNotifier.reschedule(settings: stored, rate: rate.rate)
        #if os(iOS)
        await LiveActivityController.shared.refresh()
        await LiveActivityController.shared.startIfAppropriate(manual: false)
        #endif
    }

    /// Fetches the exchange rate if today's is not cached yet. Safe to call often.
    func refreshRate() async {
        let fresh = await rates.rate(for: stored)
        if fresh != rate {
            rate = fresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
