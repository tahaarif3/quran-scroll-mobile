import DeviceActivity
import ManagedSettings
import IqraLockKit

/// Midnight reset: clear pagesReadToday and re-apply shields.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = AppGroupStore.shared
    private let managed = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        store.ensureCurrentDay()
        store.pagesReadToday = 0
        store.isLockedNow = true
        store.unlockedUntil = nil
        // Re-shield: actual tokens are applied from the app when selection is available.
        // Extensions can only clear/set via the same ManagedSettingsStore name if tokens
        // were previously set by the app in this store.
        if store.selectedAppsData != nil {
            // Leaving applications as previously configured by the app target.
            // If cleared during unlock, the app re-applies on next foreground.
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity.rawValue.contains("emergency") || activity.rawValue.contains("debug") {
            store.isLockedNow = true
            store.unlockedUntil = nil
        }
    }
}
