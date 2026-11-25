import Foundation
import Observation
import WidgetKit
import WageDripCore

/// The single source of truth for user settings in the app. Every change is validated, written
/// to the App Group, and pushed out to widgets and any other listeners.
@Observable @MainActor
final class SettingsStore {
    private var stored: Settings

    var settings: Settings {
        get { stored }
        set {
            let valid = newValue.validated()
            guard valid != stored else { return }
            stored = valid
            AppGroup.save(valid)
            WidgetCenter.shared.reloadAllTimelines()
            for listener in onChange { listener(valid) }
        }
    }

    /// Later features hook in here: notification rescheduling, Live Activity updates.
    @ObservationIgnored var onChange: [(Settings) -> Void] = []

    init() {
        stored = AppGroup.loadSettings()
    }
}
