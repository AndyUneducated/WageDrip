import Foundation
import Testing
@testable import WageDripCore

@Suite struct LiveStateTests {
    func state(_ settings: Settings, at date: Date) -> LiveState {
        LiveState(at: date, settings: settings, engine: makeEngine(settings), converter: DisplayConverter(settings: settings, rate: 1))
    }

    @Test func linesFollowSelectedPeriods() {
        let s = state(cnSettings { $0.periods = [.month, .today] }, at: at(2027, 2, 2, 13, 30))
        #expect(s.lines == [.init(period: .today, text: "¥1,000.00"), .init(period: .month, text: "¥3,000.00")])
        #expect(s.asOf == at(2027, 2, 2, 13, 30))
    }

    @Test func compactIsAlwaysToday() {
        let s = state(cnSettings { $0.periods = [.month] }, at: at(2027, 2, 2, 13, 30))
        #expect(s.lines.map(\.period) == [.month])
        #expect(s.compactText == "¥1,000.00")
    }

    @Test func countdownOnlyFixedWorking() {
        #expect(state(cnSettings(), at: at(2027, 2, 2, 13, 30)).countdownEnd == at(2027, 2, 2, 18, 0))
        #expect(state(cnSettings(), at: at(2027, 2, 2, 8, 0)).countdownEnd == nil)
    }

    @Test func finalAfterWorkEnd() {
        let s = state(cnSettings(), at: at(2027, 2, 2, 18, 0))
        #expect(s.isFinal); #expect(s.countdownEnd == nil)
        #expect(s.lines.first?.text == "¥2,000.00")
        #expect(!state(cnSettings(), at: at(2027, 2, 2, 17, 59)).isFinal)
    }

    @Test func flexNeverHasCountdownAndIsNotFinalInEvening() {
        let flex = cnSettings { $0.flexEnabled = true }
        #expect(state(flex, at: at(2027, 2, 2, 13, 30)).countdownEnd == nil)
        #expect(!state(flex, at: at(2027, 2, 2, 20, 0)).isFinal)
    }

    @Test func nextWorkStart() {
        let e = makeEngine(cnSettings())
        #expect(e.nextWorkStart(after: at(2027, 2, 4, 8, 0), calendar: shanghai) == at(2027, 2, 4, 9, 0))
        // Feb 4 is the last workday before Spring Festival; the next is the Feb 14 make-up day.
        #expect(e.nextWorkStart(after: at(2027, 2, 4, 9, 0), calendar: shanghai) == at(2027, 2, 14, 9, 0))
    }
}

@Suite struct NotificationPlanTests {
    let settings = cnSettings()
    func plan(now: Date, milestones: [Milestone], horizon: Int = 7) -> [PlannedNotification] {
        let ev = MilestoneEvaluator(engine: makeEngine(settings), converter: DisplayConverter(settings: settings, rate: 1), calendar: shanghai)
        let thresholds = Dictionary(uniqueKeysWithValues: milestones.map { ($0.id, $0.amount) })
        return NotificationPlan.plan(now: now, horizonDays: horizon, milestones: milestones, thresholds: thresholds, evaluator: ev, calendar: shanghai)
    }
    let lunch = Milestone(nameKey: "milestone.lunch", amount: 30, currency: "CNY", period: .today)

    @Test func dailyMilestoneOncePerWorkday() {
        // Monday 2027-03-01 through Sunday: five workdays.
        let p = plan(now: at(2027, 3, 1, 0, 0), milestones: [lunch])
        #expect(p.count == 5)
        #expect(p.map { DayKey($0.fireDate, calendar: shanghai).day } == [1, 2, 3, 4, 5])
        #expect(Set(p.map(\.id)).count == 5)
    }

    @Test func skipsAlreadyCrossedToday() {
        let p = plan(now: at(2027, 3, 1, 14, 0), milestones: [lunch])
        #expect(p.count == 4)
        #expect(p.first.map { DayKey($0.fireDate, calendar: shanghai) } == day(2027, 3, 2))
    }

    @Test func capsAtSixty() {
        let many = (0..<30).map { Milestone(amount: Decimal(10 + $0), currency: "CNY", period: .today) }
        #expect(plan(now: at(2027, 3, 1, 0, 0), milestones: many).count == 60)
    }

    @Test func monthMilestoneOnlyIfWithinHorizon() {
        let near = Milestone(amount: 3000, currency: "CNY", period: .month)
        let far = Milestone(amount: 25000, currency: "CNY", period: .month)
        let p = plan(now: at(2027, 3, 1, 0, 0), milestones: [near, far])
        #expect(p.map(\.milestone.id) == [near.id])
    }

    @Test func sortedByFireDate() {
        let p = plan(now: at(2027, 3, 1, 0, 0), milestones: [Milestone(amount: 600, currency: "CNY", period: .today), lunch], horizon: 1)
        #expect(p.map(\.milestone.amount) == [30, 600])
    }
}

@Suite struct HolidayCacheTests {
    @Test func badDownloadIsRejected() {
        let store = MemoryStore()
        #expect(!CNHolidays.storeDownloaded(Data("garbage".utf8), year: 2028, storage: store))
        #expect(!CNHolidays.storeDownloaded(Data(#"{"days":[]}"#.utf8), year: 2028, storage: store))
        #expect(CNHolidays.cached(storage: store).status(for: day(2027, 2, 8)) == .holiday)
    }

    @Test func downloadedOverridesBundledAndAddsYears() {
        let store = MemoryStore()
        let json = Data(#"{"days":[{"name":"x","date":"2028-01-26","isOffDay":true},{"name":"x","date":"2027-02-08","isOffDay":false}]}"#.utf8)
        #expect(CNHolidays.storeDownloaded(json, year: 2028, storage: store))
        let h = CNHolidays.cached(storage: store)
        #expect(h.status(for: day(2028, 1, 26)) == .holiday)
        #expect(h.status(for: day(2027, 2, 8)) == .makeupWorkday)
        #expect(h.status(for: day(2027, 2, 9)) == .holiday)
    }
}
