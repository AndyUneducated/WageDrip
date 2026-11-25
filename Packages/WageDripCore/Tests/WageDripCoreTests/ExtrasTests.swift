import Foundation
import Testing
@testable import WageDripCore

@Suite struct EquivalentTests {
    @Test func defaultsMatchSpec() {
        #expect(Equivalent.defaults(for: .cn).map(\.price) == [15, 10, 30, 4, 120, 7999])
        #expect(Equivalent.defaults(for: .us).map(\.price) == [5, 12, 6, dec("3.5"), 18, 999])
        #expect(Milestone.defaults(for: .cn).map(\.amount) == [30, 10, 5000, 10000, 100000])
        #expect(Milestone.defaults(for: .us).map(\.amount) == [15, 6, 2000, 10000, 100000])
        #expect(Milestone.defaults(for: .cn).map(\.period) == [.today, .today, .month, .year, .year])
        #expect(Set(Equivalent.defaults(for: .cn).map(\.id)).count == 6)
    }

    @Test func equivalentCount() {
        let tea = Equivalent.defaults(for: .cn)[0]
        #expect(tea.count(forDisplayAmount: dec("742.5"), displayCurrency: "CNY", priceRate: 1) == dec("49.5"))
        #expect(tea.count(forDisplayAmount: 30, displayCurrency: "USD", priceRate: dec("0.2")) == 10)
    }

    @Test func equivalentZeroPriceIsZero() {
        let free = Equivalent(price: 0, currency: "CNY")
        #expect(free.count(forDisplayAmount: 100, displayCurrency: "CNY", priceRate: 1) == 0)
    }
}

@Suite struct MilestoneTests {
    let engine = makeEngine(cnSettings())
    var ev: MilestoneEvaluator {
        MilestoneEvaluator(engine: engine, converter: DisplayConverter(settings: cnSettings(), rate: 1), calendar: shanghai)
    }

    @Test func dayCrossing() {
        #expect(ev.crossingDate(threshold: 1000, period: .today, after: at(2027, 2, 1, 9, 0)) == at(2027, 2, 1, 13, 30))
        #expect(ev.crossingDate(threshold: 1000, period: .today, after: at(2027, 2, 1, 0, 0)) == at(2027, 2, 1, 13, 30))
    }

    @Test func monthCrossingSkipsHolidays() {
        #expect(ev.crossingDate(threshold: 9000, period: .month, after: at(2027, 2, 1, 0, 0)) == at(2027, 2, 14, 13, 30))
    }

    @Test func yearCrossing() {
        // January 2027 pays 30000; 31000 is reached halfway through the first February workday.
        #expect(ev.crossingDate(threshold: 31000, period: .year, after: at(2027, 1, 1, 0, 0)) == at(2027, 2, 1, 13, 30))
    }

    @Test func alreadyCrossedReturnsNil() {
        #expect(ev.crossingDate(threshold: 1000, period: .today, after: at(2027, 2, 1, 14, 0)) == nil)
    }

    @Test func unreachableInPeriodReturnsNil() {
        #expect(ev.crossingDate(threshold: 5000, period: .today, after: at(2027, 2, 1, 9, 0)) == nil)
        #expect(ev.crossingDate(threshold: 40000, period: .month, after: at(2027, 2, 1, 9, 0)) == nil)
        #expect(ev.crossingDate(threshold: 30, period: .today, after: at(2027, 2, 8, 9, 0)) == nil)
    }

    @Test func crossingRespectsAfterTaxDisplay() {
        let settings = cnSettings { $0.deductionRate = dec("0.5"); $0.showAfterTax = true }
        let e = MilestoneEvaluator(engine: makeEngine(settings), converter: DisplayConverter(settings: settings, rate: 1), calendar: shanghai)
        #expect(e.crossingDate(threshold: 500, period: .today, after: at(2027, 2, 1, 9, 0)) == at(2027, 2, 1, 13, 30))
    }

    @Test func flexCrossingInEvening() {
        let settings = cnSettings { $0.flexEnabled = true }
        let e = MilestoneEvaluator(engine: makeEngine(settings), converter: DisplayConverter(settings: settings, rate: 1), calendar: shanghai)
        #expect(e.crossingDate(threshold: 1800, period: .today, after: at(2027, 2, 1, 9, 0)) == at(2027, 2, 1, 21, 0))
        #expect(e.crossingDate(threshold: 800, period: .today, after: at(2027, 2, 1, 9, 0)) == at(2027, 2, 1, 13, 30))
    }

    @Test func reachedList() {
        let milestones = Milestone.defaults(for: .cn)
        let thresholds = Dictionary(uniqueKeysWithValues: milestones.map { ($0.id, $0.amount) })
        let reached = ev.reached(milestones, at: at(2027, 2, 1, 13, 30), thresholds: thresholds)
        // By Feb 1 the year already includes all of January (30000), so the 10k mark is passed;
        // rent (5000 this month) and 100k (this year) are not.
        #expect(reached.map(\.nameKey) == ["milestone.lunch", "milestone.commute", "milestone.first10k"])
    }
}

@Suite struct TimelinePlannerTests {
    func plan(from: Date, settings: Settings = cnSettings(), maxEntries: Int = 240) -> TimelinePlan {
        TimelinePlanner.plan(from: from, engine: makeEngine(settings), calendar: shanghai, maxEntries: maxEntries)
    }

    @Test func workingHoursAreMinutely() {
        let p = plan(from: at(2027, 2, 1, 10, 0, 20), maxEntries: 5)
        #expect(p.entryDates == [at(2027, 2, 1, 10, 0, 20), at(2027, 2, 1, 10, 1), at(2027, 2, 1, 10, 2),
                                 at(2027, 2, 1, 10, 3), at(2027, 2, 1, 10, 4)])
        #expect(p.reloadAfter == at(2027, 2, 1, 10, 4))
    }

    @Test func afterWorkJumpsToMidnight() {
        #expect(plan(from: at(2027, 2, 1, 19, 0)).entryDates == [at(2027, 2, 1, 19, 0), at(2027, 2, 2, 0, 0)])
    }

    @Test func beforeWorkIncludesStart() {
        #expect(plan(from: at(2027, 2, 1, 7, 0), maxEntries: 3).entryDates
                == [at(2027, 2, 1, 7, 0), at(2027, 2, 1, 9, 0), at(2027, 2, 1, 9, 1)])
    }

    @Test func restDayJumpsToMidnight() {
        #expect(plan(from: at(2027, 2, 8, 10, 0)).entryDates == [at(2027, 2, 8, 10, 0), at(2027, 2, 9, 0, 0)])
    }

    @Test func flexEveningIsMinutely() {
        let p = plan(from: at(2027, 2, 1, 20, 0), settings: cnSettings { $0.flexEnabled = true }, maxEntries: 3)
        #expect(p.entryDates == [at(2027, 2, 1, 20, 0), at(2027, 2, 1, 20, 1), at(2027, 2, 1, 20, 2)])
    }

    @Test func endOfWorkIsAnEntryThenMidnight() {
        let p = plan(from: at(2027, 2, 1, 17, 58, 30))
        #expect(p.entryDates == [at(2027, 2, 1, 17, 58, 30), at(2027, 2, 1, 17, 59), at(2027, 2, 1, 18, 0), at(2027, 2, 2, 0, 0)])
    }

    @Test func stopsAtMidnight() {
        let flex = cnSettings { $0.flexEnabled = true }
        for start in [at(2027, 2, 1, 7, 0), at(2027, 2, 1, 23, 30), at(2027, 2, 8, 3, 0)] {
            let p = plan(from: start, settings: flex, maxEntries: 2000)
            #expect(p.entryDates.last! <= at(2027, 2, 9, 0, 0))
            #expect(p.entryDates.last == DayKey(start, calendar: shanghai).adding(days: 1, calendar: shanghai).date(in: shanghai))
            #expect(p.entryDates == p.entryDates.sorted())
            #expect(Set(p.entryDates).count == p.entryDates.count)
        }
    }
}
