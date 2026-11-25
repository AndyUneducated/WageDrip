import Foundation
import Testing
@testable import WageDripCore

@Suite struct ReceiptModelTests {
    func model(_ settings: Settings, at date: Date, rate: Decimal = 1) -> ReceiptModel {
        ReceiptModel(at: date, settings: settings, engine: makeEngine(settings),
                     converter: DisplayConverter(settings: settings, rate: rate), payToDisplayRate: rate)
    }

    @Test func allPeriodsWithTodayAsHeadline() {
        let m = model(cnSettings(), at: at(2027, 2, 2, 13, 30))
        #expect(m.headline == .init(period: .today, amount: 1000))
        #expect(m.otherLines == [.init(period: .month, amount: 3000), .init(period: .year, amount: 33000)])
        #expect(m.status == .working)
        #expect(m.dayTotal == 2000)
    }

    @Test func headlineIsHighestPrioritySelectedPeriod() {
        let m = model(cnSettings { $0.periods = [.year, .month] }, at: at(2027, 2, 2, 13, 30))
        #expect(m.headline.period == .month)
        #expect(m.otherLines.map(\.period) == [.year])
    }

    @Test func countdownOnlyWhenWorkingFixed() {
        #expect(model(cnSettings(), at: at(2027, 2, 2, 13, 30)).countdownTarget == at(2027, 2, 2, 18, 0))
        #expect(model(cnSettings(), at: at(2027, 2, 2, 19, 0)).countdownTarget == nil)
        #expect(model(cnSettings(), at: at(2027, 2, 2, 8, 0)).countdownTarget == nil)
        #expect(model(cnSettings { $0.flexEnabled = true }, at: at(2027, 2, 2, 13, 30)).countdownTarget == nil)
    }

    @Test func equivalentUsesHeadlineAmount() {
        let m = model(cnSettings(), at: at(2027, 2, 2, 13, 30))
        #expect(m.equivalent?.item.nameKey == "equiv.milkTea")
        #expect(m.equivalent?.count == Decimal(1000) / 15)
        #expect(model(cnSettings { $0.selectedEquivalentID = nil }, at: at(2027, 2, 2, 13, 30)).equivalent == nil)
    }

    @Test func amountsAreDisplayConverted() {
        let s = cnSettings { $0.deductionRate = dec("0.2"); $0.showAfterTax = true; $0.displayCurrency = "USD" }
        let m = model(s, at: at(2027, 2, 2, 13, 30), rate: dec("0.5"))
        #expect(m.headline.amount == 400)
        // Milk tea is priced in CNY (the pay currency), so its price is converted too: 15 × 0.5.
        #expect(m.equivalent?.count == Decimal(400) / dec("7.5"))
    }

    @Test func reachedMilestones() {
        let m = model(cnSettings(), at: at(2027, 2, 2, 13, 30))
        #expect(m.reachedMilestones.map(\.nameKey) == ["milestone.lunch", "milestone.commute", "milestone.first10k"])
    }
}

@Suite struct RegionSwitchTests {
    @Test func switchKeepsCustomisedFields() {
        var s = Settings.defaults(for: .cn)
        s.payCurrency = "EUR"
        s.equivalents[0].price = 99
        s.monthlyPay = 12345
        let t = s.switchingRegion(to: .us)
        #expect(t.region == .us)
        #expect(t.payCurrency == "EUR")
        #expect(t.equivalents[0].price == 99)
        #expect(t.monthlyPay == 12345)
        #expect(t.displayCurrency == "USD")
        #expect(t.holidayCalendar == .us)
        #expect(t.workEnd == TimeOfDay(hour: 17, minute: 0))
        #expect(t.milestones == Milestone.defaults(for: .us))
    }

    @Test func untouchedDefaultsSwitchCompletely() {
        var expected = Settings.defaults(for: .us)
        expected.onboardingDone = false
        #expect(Settings.defaults(for: .cn).switchingRegion(to: .us) == expected)
        #expect(Settings.defaults(for: .cn).switchingRegion(to: .cn) == Settings.defaults(for: .cn))
    }

    @Test func inferRegion() {
        #expect(Settings.inferredRegion(from: Locale(identifier: "zh_CN")) == .cn)
        #expect(Settings.inferredRegion(from: Locale(identifier: "en_US")) == .us)
        #expect(Settings.inferredRegion(from: Locale(identifier: "en_GB")) == .us)
    }

    @Test func thirdCurrencyItemsAreTakenAtFaceValue() {
        var s = Settings.defaults(for: .us)
        s.displayCurrency = "CNY"
        #expect(s.rateToDisplay(from: "USD", payToDisplayRate: 7) == 7)
        #expect(s.rateToDisplay(from: "CNY", payToDisplayRate: 7) == 1)
        #expect(s.rateToDisplay(from: "EUR", payToDisplayRate: 7) == 1)
    }
}
