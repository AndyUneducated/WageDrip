#if os(iOS)
import Foundation
import WatchConnectivity
import WageDripCore

/// Sends settings, the exchange rate and downloaded holiday data to the paired Apple Watch.
/// The watch shares no storage with the phone, so this is the only way it learns anything.
/// Everything is read from the App Group at send time, so this holds no state of its own.
final class WatchSync: NSObject, WCSessionDelegate, Sendable {
    static let shared = WatchSync()

    /// Does nothing on devices that cannot pair with a watch (iPad).
    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Replaces whatever was queued before; the watch only ever needs the latest state.
    func push() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(Self.currentPayload().dictionary)
    }

    private static func currentPayload() -> WatchPayload {
        let settings = AppGroup.loadSettings()
        return WatchPayload(settings: settings,
                            payToDisplayRate: AppGroup.cachedRate(settings: settings).rate,
                            holidayFiles: CNHolidays.downloadedFiles(storage: AppGroup.defaults))
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        push()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Happens when the owner switches to another watch; a new session is needed for it.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        push()
    }

    /// The watch asks when it has nothing yet; this also wakes the phone app in the background.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(Self.currentPayload().dictionary)
    }
}
#endif
