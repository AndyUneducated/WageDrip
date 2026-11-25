import SwiftUI
import WageDripCore

@main
struct WageDripApp: App {
    @State private var store = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ShellView()
                .environment(store)
        }
    }
}

/// Placeholder screen proving the core package is wired in. Replaced by the receipt screen.
private struct ShellView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let settings = store.settings
            let snapshot = AppGroup.makeEngine(settings: settings).snapshot(at: context.date)
            let amount = AppGroup.converter(settings: settings).display(snapshot.today)
            VStack(spacing: 12) {
                Text("窝 囊 费")
                Text(MoneyFormatter.string(amount, currency: settings.displayCurrency,
                                           fractionDigits: settings.fractionDigits))
                    .font(.system(.largeTitle, design: .monospaced))
                    .contentTransition(.numericText())
                if settings.monthlyPay == 0 {
                    Button("填入示例月薪 30,000") { store.settings.monthlyPay = 30000 }
                }
            }
            .font(.system(.body, design: .monospaced))
            .padding()
        }
    }
}
