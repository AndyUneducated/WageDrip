import Foundation
import Testing
@testable import WageDripCore

final class FakeFetcher: RateFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    private var _result: Result<Decimal, Error>

    init(_ result: Result<Decimal, Error>) { _result = result }

    var calls: Int { lock.withLock { _calls } }
    func set(_ result: Result<Decimal, Error>) { lock.withLock { _result = result } }

    func fetch(base: String, quote: String) async throws -> (rate: Decimal, asOf: DayKey) {
        let result = lock.withLock { _calls += 1; return _result }
        return (try result.get(), DayKey(year: 2026, month: 11, day: 24))
    }
}

final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    init(_ now: Date) { _now = now }
    var now: Date { lock.withLock { _now } }
    func advance(days: Int) { lock.withLock { _now += TimeInterval(days * 86400) } }
}

@Suite struct ExchangeRateStoreTests {
    let fetcher = FakeFetcher(.success(dec("7.2")))
    let storage = MemoryStore()
    let clock = Clock(at(2026, 11, 24, 10, 0))
    let usdToCny: Settings = { var s = Settings.defaults(for: .us); s.displayCurrency = "CNY"; return s }()

    func makeStore() -> ExchangeRateStore {
        let clock = clock
        return ExchangeRateStore(fetcher: fetcher, storage: storage, calendar: shanghai, now: { clock.now })
    }

    @Test func sameCurrencyIsIdentity() async {
        let r = await makeStore().rate(for: Settings.defaults(for: .us))
        #expect(r == RateResult(rate: 1, source: .identity))
        #expect(fetcher.calls == 0)
    }

    @Test func manualModeUsesManualRate() async {
        var s = usdToCny; s.rateMode = .manual; s.manualRate = dec("7.1")
        let r = await makeStore().rate(for: s)
        #expect(r == RateResult(rate: dec("7.1"), source: .manual))
        #expect(fetcher.calls == 0)
    }

    @Test func fetchesOncePerDay() async {
        let store = makeStore()
        #expect(await store.rate(for: usdToCny).source == .fresh)
        let second = await store.rate(for: usdToCny)
        #expect(second.source == .cached); #expect(second.rate == dec("7.2"))
        #expect(second.asOf == day(2026, 11, 24))
        #expect(fetcher.calls == 1)
    }

    @Test func refetchesNextDay() async {
        let store = makeStore()
        _ = await store.rate(for: usdToCny)
        clock.advance(days: 1)
        fetcher.set(.success(dec("7.3")))
        #expect(await store.rate(for: usdToCny).rate == dec("7.3"))
        #expect(fetcher.calls == 2)
    }

    @Test func fetchFailureUsesCache() async {
        let store = makeStore()
        _ = await store.rate(for: usdToCny)
        clock.advance(days: 1)
        fetcher.set(.failure(URLError(.notConnectedToInternet)))
        let r = await store.rate(for: usdToCny)
        #expect(r.rate == dec("7.2")); #expect(r.source == .cached)
    }

    @Test func noCacheNoNetworkFallsBackOneToOne() async {
        fetcher.set(.failure(URLError(.notConnectedToInternet)))
        let r = await makeStore().rate(for: usdToCny)
        #expect(r == RateResult(rate: 1, source: .fallbackOneToOne))
    }

    @Test func nonPositiveRateIsRejected() async {
        fetcher.set(.success(0))
        #expect(await makeStore().rate(for: usdToCny).source == .fallbackOneToOne)
    }

    @Test func cachedRateNeverFetches() async {
        let store = makeStore()
        #expect(store.cachedRate(for: usdToCny).source == .fallbackOneToOne)
        _ = await store.rate(for: usdToCny)
        #expect(store.cachedRate(for: usdToCny).rate == dec("7.2"))
        #expect(fetcher.calls == 1)
    }

    @Test func parsesFrankfurterResponse() throws {
        let json = Data(#"{"amount":1.0,"base":"USD","date":"2026-11-24","rates":{"CNY":6.6645}}"#.utf8)
        let parsed = try FrankfurterFetcher.parse(json, quote: "CNY")
        #expect(parsed.rate == dec("6.6645")); #expect(parsed.asOf == day(2026, 11, 24))
        #expect(throws: (any Error).self) { try FrankfurterFetcher.parse(json, quote: "EUR") }
    }
}
