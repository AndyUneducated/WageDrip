import Foundation

/// An everyday item used to express an amount as "N of these".
public struct Equivalent: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// Localization key for built-in items.
    public var nameKey: String?
    /// Name typed by the user for custom items.
    public var customName: String?
    public var price: Decimal
    public var currency: String

    public init(id: UUID = UUID(), nameKey: String? = nil, customName: String? = nil, price: Decimal, currency: String) {
        self.id = id
        self.nameKey = nameKey
        self.customName = customName
        self.price = price
        self.currency = currency
    }

    public static func defaults(for region: Region) -> [Equivalent] {
        let items: [(String, String)]
        switch region {
        case .cn:
            items = [("equiv.milkTea", "15"), ("equiv.coffee", "10"), ("equiv.takeout", "30"),
                     ("equiv.subway", "4"), ("equiv.hotpot", "120"), ("equiv.iphone", "7999")]
        case .us:
            items = [("equiv.coffee", "5"), ("equiv.burrito", "12"), ("equiv.burger", "6"),
                     ("equiv.gas", "3.5"), ("equiv.streaming", "18"), ("equiv.iphone", "999")]
        }
        return items.enumerated().map { index, item in
            Equivalent(id: stableID(region: region, kind: 1, index: index), nameKey: item.0,
                       price: Decimal(string: item.1)!, currency: region.defaultCurrency)
        }
    }

    /// How many of this item `amount` buys.
    /// - Parameter priceRate: 1 unit of this item's currency = `priceRate` display currency.
    public func count(forDisplayAmount amount: Decimal, displayCurrency: String, priceRate: Decimal) -> Decimal {
        let rate = currency == displayCurrency ? 1 : priceRate
        let unit = price * rate
        guard unit > 0 else { return 0 }
        return amount / unit
    }
}

/// Built-in items get fixed IDs so defaults compare equal across launches.
func stableID(region: Region, kind: Int, index: Int) -> UUID {
    let r = region == .cn ? 1 : 2
    return UUID(uuidString: String(format: "00000000-0000-4000-8000-%04d%04d%04d", r, kind, index))!
}
