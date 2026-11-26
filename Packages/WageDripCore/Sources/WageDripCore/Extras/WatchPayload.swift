import Foundation

/// What the phone hands to the watch: everything the watch needs to work out amounts on its
/// own, with no network and no shared storage. Travels as a property-list dictionary because
/// that is what WatchConnectivity carries.
public struct WatchPayload: Equatable, Sendable {
    public var settings: Settings
    /// 1 pay currency = this many display currency.
    public var payToDisplayRate: Decimal
    /// China holiday year files downloaded since the app was built, keyed by year.
    public var holidayFiles: [Int: Data]

    public init(settings: Settings, payToDisplayRate: Decimal, holidayFiles: [Int: Data] = [:]) {
        self.settings = settings
        self.payToDisplayRate = payToDisplayRate
        self.holidayFiles = holidayFiles
    }

    private enum Key {
        static let settings = "settings"
        static let rate = "rate"
        static let holidays = "holidays"
    }

    public var dictionary: [String: Any] {
        var result: [String: Any] = [
            Key.rate: "\(payToDisplayRate)",
            Key.holidays: Dictionary(uniqueKeysWithValues: holidayFiles.map { ("\($0.key)", $0.value) }),
        ]
        if let data = settings.encoded() { result[Key.settings] = data }
        return result
    }

    /// Nil unless the dictionary carries readable settings and a positive rate.
    public init?(dictionary: [String: Any]) {
        guard let data = dictionary[Key.settings] as? Data,
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              let rateText = dictionary[Key.rate] as? String,
              let rate = Decimal(string: rateText, locale: Locale(identifier: "en_US_POSIX")), rate > 0 else { return nil }
        self.settings = settings.validated()
        payToDisplayRate = rate
        let files = dictionary[Key.holidays] as? [String: Data] ?? [:]
        holidayFiles = Dictionary(files.compactMap { key, value in Int(key).map { ($0, value) } },
                                  uniquingKeysWith: { _, new in new })
    }
}
