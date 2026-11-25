import Foundation
import Testing
@testable import WageDripCore

@Suite struct SettingsTests {
    @Test func roundTripsThroughJSON() throws {
        var s = Settings.defaults(for: .us)
        s.dayOverrides[day(2027, 2, 6)] = .work
        s.startDate = day(2027, 1, 15)
        let data = try JSONEncoder().encode(s)
        #expect(Settings.decode(from: data) == s)
    }

    @Test func overridesEncodeAsObjectKeyedByDate() throws {
        var s = Settings.defaults(for: .cn)
        s.dayOverrides[day(2027, 2, 6)] = .work
        let json = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        #expect(json.contains("\"2027-02-06\":\"work\""))
    }

    @Test func corruptDataFallsBackToDefaults() {
        #expect(Settings.decode(from: Data("{not json".utf8)) == Settings.defaults(for: .cn))
        #expect(Settings.decode(from: Data("{\"region\":\"cn\"}".utf8)) == Settings.defaults(for: .cn))
        #expect(Settings.decode(from: nil) == Settings.defaults(for: .cn))
    }

    @Test func validatedClampsOutOfRange() {
        var s = Settings.defaults(for: .cn)
        s.deductionRate = dec("1.5"); s.fractionDigits = 20; s.flexWorkWeight = -1; s.periods = []
        s.manualRate = 0; s.monthlyPay = -5
        s.workStart = TimeOfDay(hour: 19, minute: 0); s.workEnd = TimeOfDay(hour: 18, minute: 0)
        let v = s.validated()
        #expect(v.deductionRate == 1)
        #expect(v.fractionDigits == 8)
        #expect(v.flexWorkWeight == 0)
        #expect(v.periods == [.today])
        #expect(v.manualRate == 1)
        #expect(v.monthlyPay == 0)
        #expect(v.workStart == TimeOfDay(hour: 9, minute: 0))
        #expect(v.workEnd == TimeOfDay(hour: 18, minute: 0))
    }

    @Test func validSettingsAreUnchanged() {
        let s = cnSettings()
        #expect(s.validated() == s)
    }

    @Test func taxPresets() {
        #expect(TaxPreset.allCases.map(\.rate) == [dec("0.22"), dec("0.18"), dec("0.32"), dec("0.25")])
    }

    @Test func regionDefaults() {
        let cn = Settings.defaults(for: .cn), us = Settings.defaults(for: .us)
        #expect(cn.payCurrency == "CNY"); #expect(us.payCurrency == "USD")
        #expect(cn.holidayCalendar == .cn); #expect(us.holidayCalendar == .us)
        #expect(us.workEnd == TimeOfDay(hour: 17, minute: 0))
        #expect(cn.fractionDigits == 6)
        #expect(cn.flexWorkWeight == dec("0.8"))
        #expect(Settings.defaults(for: .cn) == cn)
    }
}
