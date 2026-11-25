import SwiftUI
import WageDripCore

/// The headline amount. The integer part and the first two decimals roll like a counter; the
/// finer decimals just flicker, the way a taxi meter's last digits do.
struct RollingAmountText: View {
    let amount: Decimal
    let currency: String
    let fractionDigits: Int

    var body: some View {
        let parts = MoneyFormatter.parts(amount, fractionDigits: fractionDigits)
        let coarse = String(parts.fraction.prefix(2))
        let fine = String(parts.fraction.dropFirst(2))
        let major = MoneyFormatter.symbol(for: currency) + parts.integer + (coarse.isEmpty ? "" : "." + coarse)

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: major)
                .font(ReceiptTheme.font(size: 40, weight: .medium))
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy(duration: 0.25), value: major)
            if !fine.isEmpty {
                Text(verbatim: fine)
                    .font(ReceiptTheme.font(size: 24))
                    .foregroundStyle(ReceiptTheme.inkSecondary)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(ReceiptTheme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: MoneyFormatter.string(amount, currency: currency, fractionDigits: 2)))
    }
}
