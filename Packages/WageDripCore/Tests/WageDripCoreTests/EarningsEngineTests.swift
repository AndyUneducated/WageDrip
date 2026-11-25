import Foundation
import Testing
@testable import WageDripCore

@Suite struct EarningsEngineTests {
    let engine = makeEngine(cnSettings())

    @Test func dayWageFebruary2027() { #expect(engine.dayWage(on: day(2027, 2, 1)) == 2000) }
    @Test func restDayWageIsZero() { #expect(engine.dayWage(on: day(2027, 2, 8)) == 0) }

    @Test func monthSumsToMonthlyPay() {
        #expect(engine.snapshot(at: at(2027, 2, 28, 23, 59)).month == 30000)
        #expect(engine.monthEntitlement(year: 2027, month: 2) == 30000)
    }

    @Test func everyMonthOf2027SumsExactly() {
        let e = makeEngine(cnSettings { $0.monthlyPay = dec("31415.93") })
        for m in 1...12 {
            #expect(e.monthEntitlement(year: 2027, month: m) == dec("31415.93"))
        }
        #expect(e.snapshot(at: at(2027, 12, 31, 23, 59)).year == dec("31415.93") * 12)
    }

    @Test func fixedFractionBoundaries() {
        #expect(engine.dayFraction(at: at(2027, 2, 1, 8, 59)) == 0)
        #expect(engine.dayFraction(at: at(2027, 2, 1, 9, 0)) == 0)
        #expect(engine.dayFraction(at: at(2027, 2, 1, 13, 30)) == dec("0.5"))
        #expect(engine.dayFraction(at: at(2027, 2, 1, 18, 0)) == 1)
        #expect(engine.dayFraction(at: at(2027, 2, 1, 23, 0)) == 1)
        #expect(engine.dayFraction(at: at(2027, 2, 8, 13, 30)) == 0)
    }

    @Test func flexFraction() {
        let e = makeEngine(cnSettings { $0.flexEnabled = true })
        func f(_ h: Int, _ m: Int) -> Decimal { e.dayFraction(at: at(2027, 2, 1, h, m)) }
        #expect(f(8, 0) == 0)
        #expect(f(13, 30) == dec("0.4"))
        #expect(f(18, 0) == dec("0.8"))
        #expect(f(21, 0) == dec("0.9"))
        #expect(e.dayFraction(at: at(2027, 2, 2, 0, 0)) == 0)
        #expect(e.snapshot(at: at(2027, 2, 2, 0, 0)).month == 2000)
    }

    @Test func flexWeightIsAdjustable() {
        let e = makeEngine(cnSettings { $0.flexEnabled = true; $0.flexWorkWeight = dec("0.5") })
        #expect(e.dayFraction(at: at(2027, 2, 1, 18, 0)) == dec("0.5"))
        #expect(e.dayFraction(at: at(2027, 2, 1, 21, 0)) == dec("0.75"))
    }

    @Test func flexIgnoredInHourlyMode() {
        let e = makeEngine(cnSettings { $0.payMode = .hourly; $0.hourlyPay = 100; $0.flexEnabled = true })
        #expect(e.dayFraction(at: at(2027, 2, 1, 18, 0)) == 1)
        #expect(e.snapshot(at: at(2027, 2, 1, 19, 0)).status == .afterWork)
    }

    @Test func hourlyDayWage() {
        let e = makeEngine(cnSettings { $0.payMode = .hourly; $0.hourlyPay = 100 })
        #expect(e.dayWage(on: day(2027, 2, 1)) == 900)
        #expect(e.monthEntitlement(year: 2027, month: 2) == 13500)
    }

    @Test func annualModeSumsEnabledParts() {
        let e = makeEngine(cnSettings {
            $0.payMode = .annual; $0.annualBase = 240000
            $0.annualBonus = 60000; $0.bonusEnabled = true
            $0.annualStock = 120000; $0.stockEnabled = false
        })
        #expect(e.monthlyGross == 25000)
    }

    @Test func snapshotMidday() {
        let s = engine.snapshot(at: at(2027, 2, 2, 13, 30))
        #expect(s.today == 1000)
        #expect(s.month == 3000)
        #expect(s.year == 33000)
        #expect(s.dayTotal == 2000)
        #expect(s.status == .working)
        #expect(s.workEnd == at(2027, 2, 2, 18, 0))
        #expect(s.amount(for: .month) == 3000)
    }

    @Test func statuses() {
        #expect(engine.snapshot(at: at(2027, 2, 1, 8, 0)).status == .beforeWork)
        #expect(engine.snapshot(at: at(2027, 2, 1, 19, 0)).status == .afterWork)
        let rest = engine.snapshot(at: at(2027, 2, 8, 12, 0))
        #expect(rest.status == .restDay); #expect(rest.workEnd == nil); #expect(rest.today == 0)
        let flex = makeEngine(cnSettings { $0.flexEnabled = true })
        #expect(flex.snapshot(at: at(2027, 2, 1, 19, 0)).status == .flexEvening)
    }

    @Test func afterWorkHoldsDayTotalUntilMidnight() {
        #expect(engine.snapshot(at: at(2027, 2, 1, 23, 59, 59)).today == 2000)
        #expect(engine.snapshot(at: at(2027, 2, 2, 0, 0)).today == 0)
    }

    @Test func startDateMidMonth() {
        let e = makeEngine(cnSettings { $0.startDate = day(2027, 2, 15) })
        #expect(e.monthEntitlement(year: 2027, month: 1) == 0)
        #expect(e.monthEntitlement(year: 2027, month: 2) == 20000)
        #expect(e.snapshot(at: at(2027, 2, 14, 12, 0)).today == 0)
        #expect(e.snapshot(at: at(2027, 2, 15, 18, 0)).year == 2000)
    }

    @Test func startDateInPastYearIsIgnored() {
        let e = makeEngine(cnSettings { $0.startDate = day(2025, 6, 1) })
        #expect(e.monthEntitlement(year: 2027, month: 1) == 30000)
    }

    @Test func zeroWorkdayMonthDoesNotCrash() {
        let workdays = WorkdayCalendar(provider: NoHolidays(), overrides: [:], calendar: shanghai)
        var overrides: [DayKey: DayOverride] = [:]
        for d in workdays.days(inMonthOf: day(2027, 3, 1)) { overrides[d] = .rest }
        let e = makeEngine(cnSettings { $0.dayOverrides = overrides })
        #expect(e.dayWage(on: day(2027, 3, 1)) == 0)
        #expect(e.monthEntitlement(year: 2027, month: 3) == 0)
        #expect(e.snapshot(at: at(2027, 3, 10, 12, 0)).month == 0)
    }

    @Test func zeroPayIsZeroEverywhere() {
        let s = makeEngine(Settings.defaults(for: .cn)).snapshot(at: at(2027, 2, 2, 13, 30))
        #expect(s.today == 0); #expect(s.month == 0); #expect(s.year == 0)
    }

    @Test func dstDayReachesOneAtWorkEnd() {
        // 2027-03-14 is the US spring-forward day (a Sunday); 2027-11-07 is fall-back.
        var s = Settings.defaults(for: .us)
        s.monthlyPay = 10000; s.holidayCalendar = .none
        s.dayOverrides = [day(2027, 3, 14): .work, day(2027, 11, 7): .work]
        let e = makeEngine(s, calendar: losAngeles)
        for d in [14, 7] {
            let m = d == 14 ? 3 : 11
            #expect(e.dayFraction(at: at(2027, m, d, 17, 0, in: losAngeles)) == 1)
            #expect(e.dayFraction(at: at(2027, m, d, 13, 0, in: losAngeles)) == dec("0.5"))
            #expect(e.dayFraction(at: at(2027, m, d, 8, 0, in: losAngeles)) == 0)
        }
    }

    @Test func perSecondRate() {
        #expect(engine.perSecondRate(at: at(2027, 2, 1, 10, 0)) == Decimal(2000) / Decimal(9 * 3600))
        #expect(engine.perSecondRate(at: at(2027, 2, 1, 20, 0)) == 0)
        #expect(engine.perSecondRate(at: at(2027, 2, 8, 10, 0)) == 0)
        let flex = makeEngine(cnSettings { $0.flexEnabled = true })
        #expect(flex.perSecondRate(at: at(2027, 2, 1, 20, 0)) == Decimal(400) / Decimal(6 * 3600))
    }
}
