import Foundation
import WageDripCore

/// Keeps downloaded reference data fresh. Every failure is silent: the app keeps what it has.
enum DataRefresher {
    private static let lastCheckKey = "holidays.cn.lastCheck"
    private static let interval: TimeInterval = 7 * 86400

    /// Downloads this year's and next year's China holiday files at most once a week.
    /// - Returns: true if new data was stored.
    static func refreshHolidaysIfDue() async -> Bool {
        let defaults = AppGroup.defaults
        let last = defaults.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > interval else { return false }
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        var stored = false
        var reachedServer = false
        for y in [year, year + 1] {
            guard let (data, response) = try? await URLSession.shared.data(from: CNHolidays.downloadURL(year: y)),
                  let http = response as? HTTPURLResponse else { continue }
            reachedServer = true
            if http.statusCode == 200, CNHolidays.storeDownloaded(data, year: y, storage: defaults) {
                stored = true
            }
        }
        if reachedServer {
            defaults.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        }
        return stored
    }
}
