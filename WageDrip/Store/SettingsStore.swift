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
            for listener in onChange { listener(valid) }
        }
    }

    /// Later features hook in here: notification rescheduling, Live Activity updates.
    @ObservationIgnored var onChange: [(Settings) -> Void] = []

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

    /// Fetches the exchange rate if today's is not cached yet. Safe to call often.
    func refreshRate() async {
        let fresh = await rates.rate(for: stored)
        if fresh != rate {
            rate = fresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
