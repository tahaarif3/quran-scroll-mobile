import DeviceActivity
import FamilyControls
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
        // Re-shield from the saved selection. Relying on the app to re-apply on next foreground
        // left a hole: finishing yesterday's goal cleared `shield.applications`, and if the user
        // never reopened IqraLock the apps stayed unblocked all of the next day despite the
        // counter having reset above. This extension shares the App Group and the default
        // ManagedSettingsStore, so it can restore the shield itself.
        guard let selection = FamilyActivitySelectionStore.load(from: store) else { return }
        managed.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        managed.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.contains("emergency") || activity.rawValue.contains("debug") else {
            return
        }
        store.isLockedNow = true
        store.unlockedUntil = nil
        // The window an ayah bought has run out. Re-applying the tokens here is what makes it a
        // window at all — clearing a shield is permanent until something puts it back, and the
        // app cannot be relied on to be opened.
        guard !store.goalMetToday,
              let selection = FamilyActivitySelectionStore.load(from: store) else { return }
        managed.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        managed.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }
}
