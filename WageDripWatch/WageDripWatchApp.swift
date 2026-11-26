import SwiftUI
import WageDripCore

@main
struct WageDripWatchApp: App {
    @State private var store = WatchStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, !store.hasSynced { store.requestFromPhone() }
                }
        }
    }
}

private struct WatchRootView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        if !store.hasSynced {
            WatchNotice(text: "在 iPhone 上打开窝囊费以同步")
        } else if !store.settings.onboardingDone {
            WatchNotice(text: "请先在 iPhone 上完成设置")
        } else {
            WatchReceiptView()
        }
    }
}

private struct WatchNotice: View {
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.title2)
            Text(text)
                .font(ReceiptTheme.font(.footnote))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(ReceiptTheme.ink)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReceiptTheme.paper.ignoresSafeArea())
    }
}
