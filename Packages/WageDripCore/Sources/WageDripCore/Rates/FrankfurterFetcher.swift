import Foundation

/// Daily reference rates (European Central Bank data) from frankfurter.dev. No API key.
///
/// Response shape, checked 2026-11-24:
/// `{"amount":1.0,"base":"USD","date":"2026-11-24","rates":{"CNY":6.6645}}`
public struct FrankfurterFetcher: RateFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    private struct Response: Decodable {
        let date: String
        let rates: [String: Double]
    }

    public func fetch(base: String, quote: String) async throws -> (rate: Decimal, asOf: DayKey) {
        var components = URLComponents(string: "https://api.frankfurter.dev/v1/latest")!
        components.queryItems = [URLQueryItem(name: "base", value: base), URLQueryItem(name: "symbols", value: quote)]
        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Self.parse(data, quote: quote)
    }

    static func parse(_ data: Data, quote: String) throws -> (rate: Decimal, asOf: DayKey) {
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        // Go through the shortest decimal string so 6.6645 does not become 6.66450000000000031.
        guard let value = decoded.rates[quote], let rate = Decimal(string: "\(value)"), rate > 0,
              let day = DayKey(string: decoded.date) else {
            throw URLError(.cannotParseResponse)
        }
        return (rate, day)
    }
}
