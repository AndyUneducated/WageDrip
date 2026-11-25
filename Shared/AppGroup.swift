import Foundation
import WageDripCore

/// State shared between the app and its widget extension through the App Group container.
enum AppGroup {
    static let id = "group.com.andyuneducated.wagedrip"
    static let settingsKey = "settings.v1"

    /// Falls back to standard defaults if the group container is unavailable, so the app still
    /// runs (without sharing) rather than crashing.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    static var isSharedContainerAvailable: Bool {
        UserDefaults(suiteName: id) != nil
    }

    static func loadSettings() -> Settings {
        Settings.decode(from: defaults.data(forKey: settingsKey)).validated()
    }

    static func save(_ settings: Settings) {
        defaults.set(settings.encoded(), forKey: settingsKey)
    }

    static func makeEngine(settings: Settings, calendar: Calendar = .current) -> EarningsEngine {
        let workdays = WorkdayCalendar(provider: makeHolidayProvider(settings.holidayCalendar),
                                       overrides: settings.dayOverrides, calendar: calendar)
        return EarningsEngine(settings: settings, workdays: workdays, calendar: calendar)
    }

    /// Uses only the cached exchange rate; never touches the network.
    static func converter(settings: Settings) -> DisplayConverter {
        let rate = ExchangeRateStore.cachedRate(for: settings, storage: defaults)
        return DisplayConverter(settings: settings, rate: rate.rate)
    }
}
