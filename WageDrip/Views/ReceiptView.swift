import SwiftUI
import WageDripCore

/// The main screen: a receipt that keeps printing.
struct ReceiptView: View {
    @Environment(SettingsStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                    ReceiptContent(model: store.receipt(at: context.date), date: context.date, settings: store.settings)
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 30)
                .frame(maxWidth: ReceiptTheme.maxWidth)
                .background(ReceiptTheme.paper, in: ReceiptPaper())
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(ReceiptTheme.desk)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct ReceiptContent: View {
    let model: ReceiptModel
    let date: Date
    let settings: Settings
    /// The mini receipt in the Mac menu bar drops the header and sign-off.
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact {
                VStack(spacing: 4) {
                    Text("窝 囊 费")
                        .font(ReceiptTheme.font(.headline, weight: .medium))
                        .foregroundStyle(ReceiptTheme.ink)
                    HStack(spacing: 6) {
                        Text(date, format: .dateTime.month().day().weekday())
                        Text(verbatim: "·")
                        Text(model.status.label)
                    }
                    .font(ReceiptTheme.font(.footnote))
                    .foregroundStyle(ReceiptTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                DashedDivider()
            }

            Text(model.headline.period.headlineLabel)
                .font(ReceiptTheme.font(.footnote))
                .foregroundStyle(ReceiptTheme.inkSecondary)
            RollingAmountText(amount: model.headline.amount, currency: settings.displayCurrency,
                              fractionDigits: settings.fractionDigits)

            if !model.otherLines.isEmpty {
                DashedDivider()
                ForEach(model.otherLines, id: \.period) { line in
                    ReceiptRow(label: line.period.label,
                               value: MoneyFormatter.string(line.amount, currency: settings.displayCurrency, fractionDigits: 2))
                }
            }

            if model.equivalent != nil || !model.reachedMilestones.isEmpty {
                DashedDivider()
                if let equivalent = model.equivalent {
                    HStack(alignment: .firstTextBaseline) {
                        Text("折合")
                        Text(verbatim: equivalent.item.displayName)
                        Spacer(minLength: 12)
                        Text(verbatim: "× " + MoneyFormatter.parts(equivalent.count, fractionDigits: 1).integer
                             + "." + MoneyFormatter.parts(equivalent.count, fractionDigits: 1).fraction)
                    }
                    .font(ReceiptTheme.font(.callout))
                    .foregroundStyle(ReceiptTheme.ink)
                }
                if !model.reachedMilestones.isEmpty {
                    ReceiptRow(label: "已赚回", value: model.reachedMilestones.map(\.displayName).joined(separator: " "))
                }
            }

            if !compact {
                DashedDivider()
                VStack(spacing: 4) {
                    if let target = model.countdownTarget, target > date {
                        HStack(spacing: 6) {
                            Text("距下班")
                            Text(timerInterval: date...target, countsDown: true)
                                .monospacedDigit()
                        }
                        .font(ReceiptTheme.font(.callout, weight: .medium))
                        .foregroundStyle(ReceiptTheme.ink)
                    }
                    Text(model.status.signOff)
                        .font(ReceiptTheme.font(.footnote))
                        .foregroundStyle(ReceiptTheme.inkSecondary)
                    if settings.showAfterTax {
                        Text("以上为税后估算")
                            .font(ReceiptTheme.font(.caption2))
                            .foregroundStyle(ReceiptTheme.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
        }
    }
}
