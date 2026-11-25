#if os(macOS)
import AppKit
import SwiftUI
import WageDripCore

/// Menu bar title: today's amount, ticking every second.
struct MenuBarLabel: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let amount = store.converter.display(store.engine.snapshot(at: context.date).today)
            Text(verbatim: MoneyFormatter.string(amount, currency: store.settings.displayCurrency,
                                                 fractionDigits: store.settings.fractionDigits))
                .monospacedDigit()
        }
    }
}

/// The mini receipt that drops down from the menu bar.
struct MenuBarReceipt: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                ReceiptContent(model: store.receipt(at: context.date), date: context.date,
                               settings: store.settings, compact: true)
            }
            DashedDivider()
            HStack {
                Button("打开窝囊费") {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(ReceiptTheme.font(.footnote))
        }
        .padding(16)
        .frame(width: 320)
        .background(ReceiptTheme.paper)
    }
}
#endif
