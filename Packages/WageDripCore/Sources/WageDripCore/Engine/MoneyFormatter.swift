import Foundation

/// Formats money for display. Amounts are truncated, never rounded up, so the app never shows
/// money that has not been earned yet.
public enum MoneyFormatter {
    private static let symbols: [String: String] = [
        "CNY": "¥", "USD": "$", "EUR": "€", "GBP": "£", "JPY": "JP¥",
        "HKD": "HK$", "CAD": "CA$", "AUD": "A$", "SGD": "S$",
    ]

    public static func symbol(for currency: String) -> String {
        symbols[currency] ?? "\(currency) "
    }

    /// Integer part with thousands separators, and exactly `fractionDigits` fraction digits.
    public static func parts(_ amount: Decimal, fractionDigits: Int) -> (integer: String, fraction: String) {
        let digits = min(max(fractionDigits, 0), 8)
        var value = max(amount, 0)
        var truncated = Decimal()
        NSDecimalRound(&truncated, &value, digits, .down)

        var whole = Decimal()
        NSDecimalRound(&whole, &truncated, 0, .down)
        let wholeDigits = NSDecimalNumber(decimal: whole).stringValue

        var scaled = (truncated - whole) * pow(10, digits)
        var scaledWhole = Decimal()
        NSDecimalRound(&scaledWhole, &scaled, 0, .plain)
        let raw = digits == 0 ? "" : NSDecimalNumber(decimal: scaledWhole).stringValue
        let fraction = digits == 0 ? "" : String(repeating: "0", count: max(digits - raw.count, 0)) + raw

        return (group(wholeDigits), fraction)
    }

    public static func string(_ amount: Decimal, currency: String, fractionDigits: Int, locale: Locale = .current) -> String {
        let p = parts(amount, fractionDigits: fractionDigits)
        let number = p.fraction.isEmpty ? p.integer : "\(p.integer).\(p.fraction)"
        return symbol(for: currency) + number
    }

    private static func group(_ digits: String) -> String {
        var out: [Character] = []
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0, i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return String(out.reversed())
    }
}
