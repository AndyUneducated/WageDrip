import Foundation

/// A small rolling log of when widgets reload and the Live Activity updates, kept in the App
/// Group so both the app and the extension can write to it. Shown on a hidden settings page;
/// used to learn real-world refresh cadence.
enum Diagnostics {
    private static let key = "diagnostics.log"
    private static let limit = 600

    struct Entry: Codable, Identifiable, Hashable {
        var date: Date
        var event: String
        var id: String { "\(date.timeIntervalSince1970)-\(event)" }
    }

    static func record(_ event: String) {
        var all = entries()
        all.append(Entry(date: Date(), event: event))
        AppGroup.defaults.set(try? JSONEncoder().encode(Array(all.suffix(limit))), forKey: key)
    }

    static func entries() -> [Entry] {
        AppGroup.defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }

    /// Median gap in seconds between consecutive entries whose event starts with `prefix`.
    static func medianInterval(prefix: String) -> TimeInterval? {
        let dates = entries().filter { $0.event.hasPrefix(prefix) }.map(\.date)
        guard dates.count >= 2 else { return nil }
        let gaps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) }.sorted()
        return gaps[gaps.count / 2]
    }
}
