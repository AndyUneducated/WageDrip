import Foundation

/// A wall-clock time within a day.
public struct TimeOfDay: Hashable, Codable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var secondsFromMidnight: Int { hour * 3600 + minute * 60 }

    public static func < (a: TimeOfDay, b: TimeOfDay) -> Bool {
        a.secondsFromMidnight < b.secondsFromMidnight
    }
}
