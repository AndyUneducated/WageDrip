import Foundation
import Observation
import WatchConnectivity
import WageDripCore

/// The watch's copy of the owner's settings. The watch cannot edit anything and never goes to
/// the network: it keeps the last payload the phone sent and computes amounts from that.
@Observable @MainActor
final class WatchStore: NSObject, WCSessionDelegate {
    private static let rateKey = "watch.payToDisplayRate"
    private static let syncedKey = "watch.synced"

    private(set) var settings: Settings
    private(set) var rate: Decimal
    /// False until the phone has sent something at least once.
    private(set) var hasSynced: Bool
    @ObservationIgnored private var engineCache: EarningsEngine?

    override init() {
        let defaults = AppGroup.defaults
        settings = AppGroup.loadSettings()
        rate = defaults.string(forKey: Self.rateKey).flatMap { Decimal(string: $0) } ?? 1
        hasSynced = defaults.bool(forKey: Self.syncedKey)
        super.init()
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var engine: EarningsEngine {
        if let engineCache { return engineCache }
        let engine = AppGroup.makeEngine(settings: settings)
        engineCache = engine
        return engine
    }

    func receipt(at date: Date) -> ReceiptModel {
        ReceiptModel(at: date, settings: settings, engine: engine,
                     converter: DisplayConverter(settings: settings, rate: rate), payToDisplayRate: rate)
    }

    private func apply(_ payload: WatchPayload) {
        let defaults = AppGroup.defaults
        AppGroup.save(payload.settings)
        defaults.set("\(payload.payToDisplayRate)", forKey: Self.rateKey)
        defaults.set(true, forKey: Self.syncedKey)
        for (year, data) in payload.holidayFiles {
            CNHolidays.storeDownloaded(data, year: year, storage: defaults)
        }
        settings = payload.settings
        rate = payload.payToDisplayRate
        hasSynced = true
        engineCache = nil
    }

    /// Asks the phone directly. Needed the first time, when nothing has been queued for us yet.
    func requestFromPhone() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["request": "sync"], replyHandler: { [weak self] reply in
            guard let payload = WatchPayload(dictionary: reply) else { return }
            Task { @MainActor in self?.apply(payload) }
        }, errorHandler: nil)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let payload = WatchPayload(dictionary: session.receivedApplicationContext)
        Task { @MainActor in
            if let payload { self.apply(payload) }
            if !self.hasSynced { self.requestFromPhone() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let payload = WatchPayload(dictionary: applicationContext) else { return }
        Task { @MainActor in self.apply(payload) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if !self.hasSynced { self.requestFromPhone() }
        }
    }
}
