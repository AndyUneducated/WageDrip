#if os(iOS)
import ActivityKit
import WageDripCore

struct WageActivityAttributes: ActivityAttributes {
    typealias ContentState = LiveState
    /// The workday this activity belongs to; a leftover from another day gets ended.
    var day: DayKey
}
#endif
