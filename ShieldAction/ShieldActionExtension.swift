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
            scheduleReadNotification()
            completionHandler(.close)
        case .secondaryButtonPressed:
            _ = consumeEmergencyPass()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private func scheduleReadNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ready to read?"
        content.body = "Tap to open today's pages and unlock your apps."
        content.userInfo = ["deepLink": "iqralock://read"]
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.4, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "shield_read_prompt", content: content, trigger: trigger)
        )
        store.pendingDeepLink = "iqralock://read"
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
