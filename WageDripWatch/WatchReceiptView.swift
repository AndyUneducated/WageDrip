import SwiftUI
import WageDripCore

/// The whole watch app: one small receipt. Settings are changed on the phone.
struct WatchReceiptView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        // The navigation stack gives the system clock its own bar, so the receipt scrolls under
        // it instead of colliding with it.
        NavigationStack {
            ScrollView {
                // Five times a second is plenty for a wrist; the system slows it further when the
                // wrist is down.
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    WatchReceiptContent(model: store.receipt(at: context.date), date: context.date, settings: store.settings)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .background(ReceiptTheme.paper.ignoresSafeArea())
        }
    }
}

private struct WatchReceiptContent: View {
    let model: ReceiptModel
    let date: Date
    let settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.status.label)
                .font(ReceiptTheme.font(.caption2))
                .foregroundStyle(ReceiptTheme.inkSecondary)
            Text(model.headline.period.headlineLabel)
                .font(ReceiptTheme.font(.footnote))
                .foregroundStyle(ReceiptTheme.inkSecondary)
            WatchAmountText(amount: model.headline.amount, currency: settings.displayCurrency,
                            fractionDigits: settings.fractionDigits)

            if !model.otherLines.isEmpty {
                DashedDivider()
                ForEach(model.otherLines, id: \.period) { line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(line.period.label)
                            .foregroundStyle(ReceiptTheme.inkSecondary)
                        Spacer(minLength: 6)
                        Text(verbatim: MoneyFormatter.string(line.amount, currency: settings.displayCurrency, fractionDigits: 2))
                            .foregroundStyle(ReceiptTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .font(ReceiptTheme.font(.footnote))
                }
            }

            DashedDivider()
            VStack(spacing: 2) {
                if let target = model.countdownTarget, target > date {
                    HStack(spacing: 4) {
                        Text("距下班")
                        Text(timerInterval: date...target, countsDown: true)
                            .monospacedDigit()
                    }
                    .font(ReceiptTheme.font(.footnote, weight: .medium))
                    .foregroundStyle(ReceiptTheme.ink)
                }
                Text(model.status.signOff)
                    .multilineTextAlignment(.center)
                    .font(ReceiptTheme.font(.caption2))
                    .foregroundStyle(ReceiptTheme.inkSecondary)
                if settings.showAfterTax {
                    Text("以上为税后估算")
                        .font(ReceiptTheme.font(.caption2))
                        .foregroundStyle(ReceiptTheme.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// The amount to two decimals in large type, with the finer decimals on their own line below:
/// a watch is too narrow to carry them alongside.
private struct WatchAmountText: View {
    let amount: Decimal
    let currency: String
    let fractionDigits: Int

    var body: some View {
        let parts = MoneyFormatter.parts(amount, fractionDigits: fractionDigits)
        let coarse = String(parts.fraction.prefix(2))
        let fine = String(parts.fraction.dropFirst(2))
        let major = MoneyFormatter.symbol(for: currency) + parts.integer + (coarse.isEmpty ? "" : "." + coarse)

        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: major)
                .font(ReceiptTheme.font(size: 30, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(ReceiptTheme.ink)
            if !fine.isEmpty {
                Text(verbatim: fine)
                    .font(ReceiptTheme.font(size: 15))
                    .foregroundStyle(ReceiptTheme.inkSecondary)
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: MoneyFormatter.string(amount, currency: currency, fractionDigits: 2)))
    }
}
