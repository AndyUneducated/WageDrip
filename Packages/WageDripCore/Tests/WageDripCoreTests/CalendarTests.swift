import Foundation
import Testing
@testable import WageDripCore

@Suite struct USFederalHolidaysTests {
    let h = USFederalHolidays()
    func isHoliday(_ m: Int, _ d: Int, _ y: Int = 2027) -> Bool { h.status(for: day(y, m, d)) == .holiday }

    @Test func fixedAndFloating2027() {
        #expect(isHoliday(1, 1)); #expect(isHoliday(1, 18))
        #expect(isHoliday(2, 15)); #expect(isHoliday(5, 31))
        #expect(isHoliday(6, 18)); #expect(!isHoliday(6, 19))
        #expect(isHoliday(7, 5)); #expect(!isHoliday(7, 4))
        #expect(isHoliday(9, 6)); #expect(isHoliday(10, 11))
        #expect(isHoliday(11, 11)); #expect(isHoliday(11, 25))
        #expect(isHoliday(12, 24)); #expect(!isHoliday(12, 25))
        #expect(isHoliday(12, 31))
        #expect(!isHoliday(3, 15))
    }

    @Test func elevenPerYear() {
        #expect(Set(USFederalHolidays.observedDays(year: 2026)).count == 11)
        #expect(isHoliday(11, 26, 2026)); #expect(isHoliday(7, 3, 2026)); #expect(isHoliday(5, 25, 2026))
    }
}

@Suite struct CNHolidaysTests {
    @Test func bundled2027() {
        let h = CNHolidays.bundled()
        #expect(h.status(for: day(2027, 2, 8)) == .holiday)
        #expect(h.status(for: day(2027, 2, 5)) == .holiday)
        #expect(h.status(for: day(2027, 2, 13)) == .holiday)
        for d in [day(2027, 1, 31), day(2027, 2, 14), day(2027, 5, 8), day(2027, 9, 26), day(2027, 10, 9)] {
            #expect(h.status(for: d) == .makeupWorkday)
        }
        #expect(h.status(for: day(2027, 3, 3)) == nil)
        #expect(h.status(for: day(2026, 10, 1)) == .holiday)
    }

    @Test func missingYearReturnsNil() {
        #expect(CNHolidays.bundled().status(for: day(2035, 10, 1)) == nil)
    }

    @Test func malformedJSONIsIgnored() {
        let h = CNHolidays(jsonFiles: [Data("oops".utf8)])
        #expect(h.status(for: day(2027, 2, 8)) == nil)
        #expect(h.isEmpty)
    }
}

@Suite struct WorkdayCalendarTests {
    @Test func february2027Has15Workdays() {
        let c = WorkdayCalendar(provider: CNHolidays.bundled(), overrides: [:], calendar: shanghai)
        #expect(c.workdays(inMonthOf: day(2027, 2, 1)).count == 15)
    }

    @Test func overrideWins() {
        let sat = day(2027, 3, 6), mon = day(2027, 3, 8), holiday = day(2027, 2, 8)
        let c = WorkdayCalendar(provider: CNHolidays.bundled(), overrides: [sat: .work, mon: .rest, holiday: .work], calendar: shanghai)
        #expect(c.isWorkday(sat)); #expect(!c.isWorkday(mon)); #expect(c.isWorkday(holiday))
    }

    @Test func november2026USHas19Workdays() {
        let c = WorkdayCalendar(provider: USFederalHolidays(), overrides: [:], calendar: losAngeles)
        #expect(c.workdays(inMonthOf: day(2026, 11, 1)).count == 19)
    }

    @Test func yearWithoutDataFallsBackToWeekdays() {
        let c = WorkdayCalendar(provider: CNHolidays.bundled(), overrides: [:], calendar: shanghai)
        #expect(c.isWorkday(day(2035, 10, 1)))      // a Monday
        #expect(!c.isWorkday(day(2035, 10, 6)))     // a Saturday
    }
}
