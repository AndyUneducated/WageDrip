import Foundation

/// Everything the receipt shows at one instant, as plain data so it can be tested without UI.
/// All amounts are in the display currency, after the deduction if the user asked for that.
public struct ReceiptModel: Equatable, Sendable {
    public struct Line: Equatable, Sendable {
        public var period: Period
        public var amount: Decimal
    }

    public struct EquivalentLine: Equatable, Sendable {
        public var item: Equivalent
        public var count: Decimal
    }

    public var status: WorkStatus
    /// The highest-priority selected period: today, else month, else year.
    public var headline: Line
    public var otherLines: [Line]
    public var equivalent: EquivalentLine?
    public var reachedMilestones: [Milestone]
    /// End of work, only while working fixed hours.
    public var countdownTarget: Date?
    /// What the whole day pays, for the "settled" state.
    public var dayTotal: Decimal

    public init(at date: Date, settings: Settings, engine: EarningsEngine, converter: DisplayConverter,
                payToDisplayRate: Decimal) {
        let snapshot = engine.snapshot(at: date)
        let periods = (settings.periods.isEmpty ? [.today] : settings.periods).sorted()
        let lines = periods.map { Line(period: $0, amount: converter.display(snapshot.amount(for: $0))) }

        status = snapshot.status
        headline = lines[0]
        otherLines = Array(lines.dropFirst())
        dayTotal = converter.display(snapshot.dayTotal)

        let headlineAmount = lines[0].amount
        equivalent = settings.equivalents.first { $0.id == settings.selectedEquivalentID }.map { item in
            let rate = settings.rateToDisplay(from: item.currency, payToDisplayRate: payToDisplayRate)
            return EquivalentLine(item: item, count: item.count(forDisplayAmount: headlineAmount,
                                                               displayCurrency: settings.displayCurrency, priceRate: rate))
        }

        reachedMilestones = settings.milestones.filter { m in
            let threshold = m.amount * settings.rateToDisplay(from: m.currency, payToDisplayRate: payToDisplayRate)
            return threshold > 0 && converter.display(snapshot.amount(for: m.period)) >= threshold
        }

        let fixedHours = !(settings.flexEnabled && settings.payMode != .hourly)
        countdownTarget = snapshot.status == .working && fixedHours ? snapshot.workEnd : nil
    }
}

extension Settings {
    /// Rate from an item's own currency into the display currency. Only the pay-to-display rate is
    /// known, so items priced in any third currency are taken at face value.
    public func rateToDisplay(from currency: String, payToDisplayRate: Decimal) -> Decimal {
        if currency == displayCurrency { return 1 }
        if currency == payCurrency { return payToDisplayRate }
        return 1
    }

    /// Milestone thresholds converted into the display currency.
    public func milestoneThresholds(payToDisplayRate: Decimal) -> [UUID: Decimal] {
        Dictionary(milestones.map { ($0.id, $0.amount * rateToDisplay(from: $0.currency, payToDisplayRate: payToDisplayRate)) },
                   uniquingKeysWith: { a, _ in a })
    }

    /// Switches region, replacing only the fields still at the old region's defaults so that
    /// anything the user customised is kept.
    public func switchingRegion(to new: Region) -> Settings {
        guard new != region else { return self }
        let old = Settings.defaults(for: region), fresh = Settings.defaults(for: new)
        var s = self
        s.region = new
        if payCurrency == old.payCurrency { s.payCurrency = fresh.payCurrency }
        if displayCurrency == old.displayCurrency { s.displayCurrency = fresh.displayCurrency }
        if holidayCalendar == old.holidayCalendar { s.holidayCalendar = fresh.holidayCalendar }
        if workStart == old.workStart, workEnd == old.workEnd {
            s.workStart = fresh.workStart
            s.workEnd = fresh.workEnd
        }
        if equivalents == old.equivalents {
            s.equivalents = fresh.equivalents
            s.selectedEquivalentID = fresh.selectedEquivalentID
        }
        if milestones == old.milestones { s.milestones = fresh.milestones }
        return s
    }

    public static func inferredRegion(from locale: Locale) -> Region {
        locale.region?.identifier == "CN" ? .cn : .us
    }
}
