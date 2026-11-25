#if os(macOS)
import AppKit
import SwiftUI
import WageDripCore

/// Drives the menu bar title. A menu bar label is rendered as a static snapshot, so a
/// self-updating view inside it never refreshes; the title has to change as observed state.
@Observable @MainActor
final class MenuBarTicker {
    private(set) var title = ""
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private weak var store: SettingsStore?

    func start(store: SettingsStore) {
        self.store = store
        tick()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let store else { return }
        let amount = store.converter.display(store.engine.snapshot(at: Date()).today)
        // Two decimals: finer digits would make the title jitter and crowd the menu bar.
        title = MoneyFormatter.string(amount, currency: store.settings.displayCurrency,
                                      fractionDigits: min(store.settings.fractionDigits, 2))
    }
}

/// Menu bar title: a drop and today's amount, ticking every second.
struct MenuBarLabel: View {
    let ticker: MenuBarTicker

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
            Text(verbatim: ticker.title)
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
