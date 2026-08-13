import ManagedSettings
import IqraLockKit
import UserNotifications

/// Primary "Read now" cannot launch the host app — posts a deep-link notification, then `.close`.
/// Emergency pass clears the ManagedSettings shield for a short window.
final class ShieldActionExtension: ShieldActionDelegate {
    private let store = AppGroupStore.shared

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        perform(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        perform(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        perform(action: action, completionHandler: completionHandler)
    }

    private func perform(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(recordAyahRead())
        case .secondaryButtonPressed:
            _ = consumeEmergencyPass()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    /// Credits one ayah and decides whether that finished the day.
    ///
    /// `.defer` keeps the shield up and re-runs the configuration, which serves the next ayah —
    /// so the same button is both "I've read it" and "read another", without needing a third
    /// button the API does not offer. Reading happens on the lock screen; the app never opens.
    private func recordAyahRead() -> ShieldActionResponse {
        let record = store.recordAyah()

        guard record.counted else {
            // Tapped within the minimum interval. Deferring re-presents the same ayah, which is
            // the correct feedback: it has not been counted, so it is still there to read.
            return .defer
        }

        guard record.goalMet else { return .defer }

        // Goal complete — lift the shield for the rest of the day and let the app through.
        store.isLockedNow = false
        let calendar = Calendar.current
        store.unlockedUntil = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())
        )
        ManagedSettingsStore().shield.applications = nil
        ManagedSettingsStore().shield.applicationCategories = nil
        scheduleUnlockedNotification()
        return .close
    }

    private func scheduleUnlockedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Apps unlocked"
        content.body = "You finished today's reading. Your apps are open until tomorrow."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.4, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "shield_unlocked", content: content, trigger: trigger)
        )
    }

    @discardableResult
    private func consumeEmergencyPass() -> Bool {
        store.resetEmergencyPassesIfNeeded()
        guard store.emergencyPassesRemaining > 0 else { return false }
        store.emergencyPassesRemaining -= 1
        store.isLockedNow = false
        store.unlockedUntil = Date().addingTimeInterval(15 * 60)
        let managed = ManagedSettingsStore()
        managed.shield.applications = nil
        return true
    }
}
