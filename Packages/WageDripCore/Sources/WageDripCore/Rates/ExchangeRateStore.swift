import Foundation

public protocol RateFetching: Sendable {
    /// 1 `base` = `rate` `quote`, as of the given day.
    func fetch(base: String, quote: String) async throws -> (rate: Decimal, asOf: DayKey)
}

/// The slice of UserDefaults the core needs, so tests can swap in memory storage.
public protocol KeyValueStoring: Sendable {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStoring {
    public func setData(_ data: Data?, forKey key: String) {
        set(data, forKey: key)
    }
}

public struct RateResult: Equatable, Sendable {
    public enum Source: Sendable, Equatable {
        /// Pay and display currency are the same.
        case identity
        case manual
        /// Fetched just now.
        case fresh
        case cached
        /// No rate available at all: shown 1:1 and must be flagged to the user.
        case fallbackOneToOne
    }

    public var rate: Decimal
    public var source: Source
    /// The day the rate is quoted for, when known.
    public var asOf: DayKey?

    public init(rate: Decimal, source: Source, asOf: DayKey? = nil) {
        self.rate = rate
        self.source = source
        self.asOf = asOf
    }
}

/// Resolves the pay-to-display exchange rate, fetching at most once per day per currency pair
/// and falling back to the last cached value when the network is unavailable.
public actor ExchangeRateStore {
    private struct Cached: Codable {
        var rate: Decimal
        var asOf: DayKey
        var fetchedOn: DayKey
    }

    private let fetcher: RateFetching
    private let storage: KeyValueStoring
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(fetcher: RateFetching, storage: KeyValueStoring,
                calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fetcher = fetcher
        self.storage = storage
        self.calendar = calendar
        self.now = now
    }

    /// May hit the network.
    public func rate(for settings: Settings) async -> RateResult {
        if let fixed = Self.fixedRate(for: settings) { return fixed }
        let key = Self.key(settings)
        let today = DayKey(now(), calendar: calendar)
        let cached = Self.load(key, from: storage)
        if let cached, cached.fetchedOn == today {
            return RateResult(rate: cached.rate, source: .cached, asOf: cached.asOf)
        }
        do {
            let fetched = try await fetcher.fetch(base: settings.payCurrency, quote: settings.displayCurrency)
            guard fetched.rate > 0 else { throw URLError(.cannotParseResponse) }
            let entry = Cached(rate: fetched.rate, asOf: fetched.asOf, fetchedOn: today)
            storage.setData(try? JSONEncoder().encode(entry), forKey: key)
            return RateResult(rate: fetched.rate, source: .fresh, asOf: fetched.asOf)
        } catch {
            if let cached {
                return RateResult(rate: cached.rate, source: .cached, asOf: cached.asOf)
            }
            return RateResult(rate: 1, source: .fallbackOneToOne)
        }
    }

    /// Never hits the network. For widgets and other places that cannot wait.
    public nonisolated func cachedRate(for settings: Settings) -> RateResult {
        Self.cachedRate(for: settings, storage: storage)
    }

    public static func cachedRate(for settings: Settings, storage: KeyValueStoring) -> RateResult {
        if let fixed = fixedRate(for: settings) { return fixed }
        if let cached = load(key(settings), from: storage) {
            return RateResult(rate: cached.rate, source: .cached, asOf: cached.asOf)
        }
        return RateResult(rate: 1, source: .fallbackOneToOne)
    }

    private static func fixedRate(for settings: Settings) -> RateResult? {
        if settings.payCurrency == settings.displayCurrency {
            return RateResult(rate: 1, source: .identity)
        }
        if settings.rateMode == .manual {
            return RateResult(rate: settings.manualRate, source: .manual)
        }
        return nil
    }

    private static func key(_ settings: Settings) -> String {
        "rate.\(settings.payCurrency).\(settings.displayCurrency)"
    }

    private static func load(_ key: String, from storage: KeyValueStoring) -> Cached? {
        storage.data(forKey: key).flatMap { try? JSONDecoder().decode(Cached.self, from: $0) }
    }
}
