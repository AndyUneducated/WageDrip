import Foundation

/// A small rolling log of when widgets reload and the Live Activity updates, kept in the App
/// Group so both the app and the extension can write to it. Shown on a hidden settings page;
/// used to learn real-world refresh cadence.
enum Diagnostics {
    /// The app and the widget extension each write their own list. Sharing one list lost entries
    /// whenever both read, appended and wrote back at the same time.
    private static let prefix = "diagnostics.log"
    private static let limit = 400
    private static let writers = ["app", "widgets"]

    private static var ownKey: String {
        let isExtension = Bundle.main.bundleURL.pathExtension == "appex"
        return "\(prefix).\(isExtension ? "widgets" : "app")"
    }

    struct Entry: Codable, Identifiable, Hashable {
        var date: Date
        var event: String
        var id: String { "\(date.timeIntervalSince1970)-\(event)" }
    }

    private static func load(_ key: String) -> [Entry] {
        AppGroup.defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    static func record(_ event: String) {
        var own = load(ownKey)
        own.append(Entry(date: Date(), event: event))
        AppGroup.defaults.set(try? JSONEncoder().encode(Array(own.suffix(limit))), forKey: ownKey)
    }

    /// Everything from both writers (and the older shared list), oldest first.
    static func entries() -> [Entry] {
        ([prefix] + writers.map { "\(prefix).\($0)" }).flatMap(load).sorted { $0.date < $1.date }
    }

    static func clear() {
        for key in [prefix] + writers.map({ "\(prefix).\($0)" }) {
            AppGroup.defaults.removeObject(forKey: key)
        }
    }

    /// Median gap in seconds between consecutive entries whose event starts with `prefix`.
    static func medianInterval(prefix: String) -> TimeInterval? {
        let dates = entries().filter { $0.event.hasPrefix(prefix) }.map(\.date)
        guard dates.count >= 2 else { return nil }
        let gaps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) }.sorted()
        return gaps[gaps.count / 2]
    }
}
