import SwiftUI
import WageDripCore

/// A labelled decimal input. Backed by text so that every keystroke counts (number pads have no
/// return key) and a zero value shows as an empty field instead of a "0" the user must delete.
struct AmountField: View {
    let label: LocalizedStringKey
    @Binding var value: Decimal
    var suffix: String = ""
    var showsLabel = true
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if showsLabel {
                LabeledContent { field } label: { Text(label) }
            } else {
                field
            }
        }
        .onAppear { text = Self.format(value) }
        .onChange(of: text) { _, new in
            let parsed = Self.parse(new)
            if parsed != value { value = parsed }
        }
        .onChange(of: value) { _, new in
            // Reflect outside changes (presets, validation) unless the user is mid-typing.
            if !focused, Self.parse(text) != new { text = Self.format(new) }
        }
    }

    private var field: some View {
        HStack(spacing: 4) {
            TextField(label, text: $text, prompt: Text(verbatim: "0"))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .labelsHidden()
                .focused($focused)
            if !suffix.isEmpty {
                Text(verbatim: suffix).foregroundStyle(.secondary)
            }
        }
    }

    static func parse(_ text: String) -> Decimal {
        let cleaned = text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
            .trimmingCharacters(in: .whitespaces)
        return max(Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) ?? 0, 0)
    }

    static func format(_ value: Decimal) -> String {
        value == 0 ? "" : NSDecimalNumber(decimal: value).stringValue
    }
}

struct CurrencyPicker: View {
    let label: LocalizedStringKey
    @Binding var selection: String

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(supportedCurrencies, id: \.self) { code in
                Text(verbatim: code).tag(code)
            }
        }
    }
}

extension Binding where Value == TimeOfDay {
    /// Bridges to DatePicker, which works in Dates.
    var asDate: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1,
                                                           hour: wrappedValue.hour, minute: wrappedValue.minute)) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                wrappedValue = TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
            }
        )
    }
}

extension Binding where Value == Decimal {
    var asDouble: Binding<Double> {
        Binding<Double>(
            get: { NSDecimalNumber(decimal: wrappedValue).doubleValue },
            set: { wrappedValue = Decimal(string: String(format: "%.2f", $0)) ?? 0 }
        )
    }
}

func percentText(_ value: Decimal) -> String {
    "\(NSDecimalNumber(decimal: value * 100).intValue)%"
}

/// Pay amount inputs shared by onboarding and settings.
struct PayInputs: View {
    @Binding var settings: Settings

    var body: some View {
        Picker("薪酬方式", selection: $settings.payMode) {
            ForEach(PayMode.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)

        switch settings.payMode {
        case .annual:
            AmountField(label: "年度底薪", value: $settings.annualBase, suffix: settings.payCurrency)
            Toggle("含现金奖金", isOn: $settings.bonusEnabled)
            if settings.bonusEnabled {
                AmountField(label: "年度奖金", value: $settings.annualBonus, suffix: settings.payCurrency)
            }
            Toggle("含股票或期权", isOn: $settings.stockEnabled)
            if settings.stockEnabled {
                AmountField(label: "年度股票价值", value: $settings.annualStock, suffix: settings.payCurrency)
            }
        case .monthly:
            AmountField(label: "月薪", value: $settings.monthlyPay, suffix: settings.payCurrency)
        case .hourly:
            AmountField(label: "时薪", value: $settings.hourlyPay, suffix: settings.payCurrency)
        }
        CurrencyPicker(label: "薪酬货币", selection: $settings.payCurrency)
    }
}

/// Work start and end pickers that refuse a start at or after the end.
struct WorkHoursInputs: View {
    @Binding var settings: Settings
    @State private var showInvalid = false

    var body: some View {
        DatePicker("上班时间", selection: guarded(\.workStart).asDate, displayedComponents: .hourAndMinute)
        DatePicker("下班时间", selection: guarded(\.workEnd).asDate, displayedComponents: .hourAndMinute)
        if showInvalid {
            Text("上班时间必须早于下班时间，暂不支持跨午夜的夜班。")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func guarded(_ keyPath: WritableKeyPath<Settings, TimeOfDay>) -> Binding<TimeOfDay> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                var candidate = settings
                candidate[keyPath: keyPath] = newValue
                if candidate.workStart < candidate.workEnd {
                    settings = candidate
                    showInvalid = false
                } else {
                    showInvalid = true
                }
            }
        )
    }
}
