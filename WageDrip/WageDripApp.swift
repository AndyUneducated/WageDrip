import SwiftUI
import WageDripCore

@main
struct WageDripApp: App {
    @State private var store = SettingsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.refreshRate() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refreshRate() }
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 460, height: 720)
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
