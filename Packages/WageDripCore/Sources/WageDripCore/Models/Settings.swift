import Foundation

public enum PayMode: String, Codable, Sendable, CaseIterable { case annual, monthly, hourly }
public enum Region: String, Codable, Sendable, CaseIterable { case cn, us }
public enum HolidayCalendarKind: String, Codable, Sendable, CaseIterable { case cn, us, none }
public enum DayOverride: String, Codable, Sendable { case work, rest }
public enum RateMode: String, Codable, Sendable { case auto, manual }

public enum Period: String, Codable, CaseIterable, Sendable, Comparable {
    case today, month, year

    /// Display priority: today first, then month, then year.
    public var priority: Int { Period.allCases.firstIndex(of: self) ?? 0 }
    public static func < (a: Period, b: Period) -> Bool { a.priority < b.priority }
}

/// Rough, user-adjustable deduction presets. Reference values only.
public enum TaxPreset: CaseIterable, Sendable {
    case cnTier1, cnOther, usTier1, usOther

    public var rate: Decimal {
        switch self {
        case .cnTier1: Decimal(string: "0.22")!
        case .cnOther: Decimal(string: "0.18")!
        case .usTier1: Decimal(string: "0.32")!
        case .usOther: Decimal(string: "0.25")!
        }
    }
}

/// Everything the user can configure. Stored as one JSON blob in the App Group.
public struct Settings: Codable, Equatable, Sendable {
    public var region: Region
    public var payMode: PayMode
    public var annualBase: Decimal
    public var annualBonus: Decimal
    public var annualStock: Decimal
    public var monthlyPay: Decimal
    public var hourlyPay: Decimal
    public var bonusEnabled: Bool
    public var stockEnabled: Bool
    /// ISO 4217 code the pay amounts are entered in.
    public var payCurrency: String
    /// 0...1
    public var deductionRate: Decimal
    public var showAfterTax: Bool
    public var workStart: TimeOfDay
    public var workEnd: TimeOfDay
    public var flexEnabled: Bool
    /// Share of the day's pay earned between work start and end. The evening share is 1 minus this.
    public var flexWorkWeight: Decimal
    public var startDate: DayKey?
    public var holidayCalendar: HolidayCalendarKind
    public var dayOverrides: [DayKey: DayOverride]
    public var periods: Set<Period>
    /// 0...8
    public var fractionDigits: Int
    public var displayCurrency: String
    public var rateMode: RateMode
    /// 1 pay currency = manualRate display currency.
    public var manualRate: Decimal
    public var equivalents: [Equivalent]
    public var selectedEquivalentID: UUID?
    public var milestones: [Milestone]
    public var milestoneAlertsEnabled: Bool
    public var autoStartLiveActivity: Bool
    public var onboardingDone: Bool

    public static func defaults(for region: Region) -> Settings {
        let equivalents = Equivalent.defaults(for: region)
        let currency = region.defaultCurrency
        return Settings(
            region: region,
            payMode: .monthly,
            annualBase: 0, annualBonus: 0, annualStock: 0, monthlyPay: 0, hourlyPay: 0,
            bonusEnabled: false, stockEnabled: false,
            payCurrency: currency,
            deductionRate: 0,
            showAfterTax: false,
            workStart: region.defaultWorkStart,
            workEnd: region.defaultWorkEnd,
            flexEnabled: false,
            flexWorkWeight: Decimal(string: "0.8")!,
            startDate: nil,
            holidayCalendar: region.defaultHolidayCalendar,
            dayOverrides: [:],
            periods: Set(Period.allCases),
            fractionDigits: 6,
            displayCurrency: currency,
            rateMode: .auto,
            manualRate: 1,
            equivalents: equivalents,
            selectedEquivalentID: equivalents.first?.id,
            milestones: Milestone.defaults(for: region),
            milestoneAlertsEnabled: false,
            autoStartLiveActivity: true,
            onboardingDone: false
        )
    }

    /// Decodes stored settings. Missing or unreadable data yields the defaults, never a crash.
    public static func decode(from data: Data?) -> Settings {
        guard let data, let s = try? JSONDecoder().decode(Settings.self, from: data) else {
            return defaults(for: .cn)
        }
        return s
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Returns a copy with out-of-range values pulled back into range.
    public func validated() -> Settings {
        var s = self
        func nonNegative(_ v: Decimal) -> Decimal { max(v, 0) }
        s.annualBase = nonNegative(annualBase)
        s.annualBonus = nonNegative(annualBonus)
        s.annualStock = nonNegative(annualStock)
        s.monthlyPay = nonNegative(monthlyPay)
        s.hourlyPay = nonNegative(hourlyPay)
        s.deductionRate = min(max(deductionRate, 0), 1)
        s.flexWorkWeight = min(max(flexWorkWeight, 0), 1)
        s.fractionDigits = min(max(fractionDigits, 0), 8)
        if s.periods.isEmpty { s.periods = [.today] }
        if s.manualRate <= 0 { s.manualRate = 1 }
        let validTimes = (0..<24).contains(workStart.hour) && (0..<60).contains(workStart.minute)
            && (0..<24).contains(workEnd.hour) && (0..<60).contains(workEnd.minute)
        if !validTimes || !(workStart < workEnd) {
            s.workStart = region.defaultWorkStart
            s.workEnd = region.defaultWorkEnd
        }
        if let id = s.selectedEquivalentID, !s.equivalents.contains(where: { $0.id == id }) {
            s.selectedEquivalentID = s.equivalents.first?.id
        }
        return s
    }
}
