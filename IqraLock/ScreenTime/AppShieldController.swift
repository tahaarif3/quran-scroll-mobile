import Foundation
import IqraLockKit

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
import DeviceActivity

/// App-target helper that can read `ApplicationToken`s and drive ManagedSettings.
enum AppShieldController {
    private static let managed = ManagedSettingsStore()

    static func applyFromSavedSelection(store: AppGroupStore = .shared) {
        guard let selection = FamilyActivitySelectionStore.load(from: store) else { return }
        managed.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        managed.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.isLockedNow = true
    }

    static func clear() {
        managed.shield.applications = nil
        managed.shield.applicationCategories = nil
        AppGroupStore.shared.isLockedNow = false
    }

    static func scheduleDailyReset() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        try? center.startMonitoring(.daily, during: schedule)
    }

    #if DEBUG
    /// Short schedule so midnight re-shield can be verified in minutes.
    static func scheduleDebugReshield(minutes: Int = 2) {
        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        var end = now
        end.minute = (end.minute ?? 0) + minutes
        let schedule = DeviceActivitySchedule(
            intervalStart: now,
            intervalEnd: end,
            repeats: false
        )
        try? DeviceActivityCenter().startMonitoring(.debugShort, during: schedule)
    }
    #endif
}
#endif
