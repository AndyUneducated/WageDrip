import Foundation
import Testing
@testable import WageDripCore

@Suite struct DisplayConverterTests {
    @Test func afterTaxAndRate() {
        let c = DisplayConverter(settings: cnSettings { $0.deductionRate = dec("0.22"); $0.showAfterTax = true }, rate: dec("0.14"))
        #expect(c.display(1000) == dec("109.2"))
    }

    @Test func preTaxIgnoresDeduction() {
        let c = DisplayConverter(settings: cnSettings { $0.deductionRate = dec("0.22") }, rate: 1)
        #expect(c.display(1000) == 1000)
    }
}

@Suite struct MoneyFormatterTests {
    @Test func truncatesNotRounds() {
        #expect(MoneyFormatter.parts(dec("742.3186429"), fractionDigits: 6) == ("742", "318642"))
        #expect(MoneyFormatter.parts(dec("0.999"), fractionDigits: 2) == ("0", "99"))
        #expect(MoneyFormatter.parts(dec("14105.5"), fractionDigits: 2) == ("14,105", "50"))
        #expect(MoneyFormatter.parts(12, fractionDigits: 0) == ("12", ""))
        #expect(MoneyFormatter.parts(dec("12.99"), fractionDigits: 0) == ("12", ""))
        #expect(MoneyFormatter.parts(dec("1.000001"), fractionDigits: 8) == ("1", "00000100"))
        #expect(MoneyFormatter.parts(1234567, fractionDigits: 2) == ("1,234,567", "00"))
        #expect(MoneyFormatter.parts(0, fractionDigits: 4) == ("0", "0000"))
    }

    @Test func repeatingDecimalsStayTruncated() {
        let third = Decimal(2000) / Decimal(3)
        #expect(MoneyFormatter.parts(third, fractionDigits: 6) == ("666", "666666"))
    }

    @Test func currencySymbol() {
        #expect(MoneyFormatter.string(dec("742.31"), currency: "CNY", fractionDigits: 2) == "¥742.31")
        #expect(MoneyFormatter.string(1234, currency: "USD", fractionDigits: 2) == "$1,234.00")
        #expect(MoneyFormatter.string(5, currency: "CHF", fractionDigits: 0) == "CHF 5")
    }
}
