import SwiftUI
import WageDripCore

@main
struct WageDripApp: App {
    @State private var store: SettingsStore
    #if os(macOS)
    @State private var ticker: MenuBarTicker
    #endif

    init() {
        let store = SettingsStore()
        _store = State(initialValue: store)
        #if os(iOS)
        WatchSync.shared.start()
        #endif
        #if os(macOS)
        // Started here rather than from a view: the menu bar item must tick even when no
        // window has been opened.
        let ticker = MenuBarTicker()
        ticker.start(store: store)
        _ticker = State(initialValue: ticker)
        #endif
    }
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(store)
                .task { await store.appBecameActive() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task { await store.appBecameActive() }
                    case .background:
                        #if os(iOS)
                        LiveActivityController.shared.scheduleBackgroundRefresh()
                        Task { await LiveActivityController.shared.refresh() }
                        #endif
                    default:
                        break
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 460, height: 720)
        #endif
        #if os(iOS)
        .backgroundTask(.appRefresh(LiveActivityController.refreshID)) {
            await LiveActivityController.shared.refresh()
            await LiveActivityController.shared.scheduleBackgroundRefresh()
        }
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarReceipt()
                .environment(store)
        } label: {
            MenuBarLabel(ticker: ticker)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

private struct RootView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        if store.settings.onboardingDone {
            ReceiptView()
        } else {
            OnboardingView()
        }
    }
}

#if os(iOS)
import UIKit

/// The system launches the app in the background when a scheduled Live Activity starts and for
/// background refreshes. No scene exists then, so the refresh has to be kicked off from here.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in
            await LiveActivityController.shared.refresh()
            LiveActivityController.shared.scheduleBackgroundRefresh()
        }
        return true
    }
}
#endif
