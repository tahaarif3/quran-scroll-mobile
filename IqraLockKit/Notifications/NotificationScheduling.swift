import Foundation
import UserNotifications

public protocol NotificationScheduling: AnyObject, Sendable {
    func requestPermission() async -> Bool
    func scheduleDailyReminder(hour: Int, minute: Int)
    func scheduleStreakAtRiskIfNeeded(goalMet: Bool)
    func scheduleAppsUnlocked()
    func scheduleReadPromptFromShield()
}

public final class LocalNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time to read"
        content.body = "Your daily pages are waiting. Unlock your apps with Qur'an."
        content.userInfo = ["deepLink": "iqralock://read"]
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger))
    }

    public func scheduleStreakAtRiskIfNeeded(goalMet: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_at_risk"])
        guard !goalMet else { return }
        let content = UNMutableNotificationContent()
        content.title = "Streak at risk"
        content.body = "Finish today's pages before midnight to keep your streak."
        content.userInfo = ["deepLink": "iqralock://read"]
        var comps = DateComponents()
        comps.hour = 20
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: "streak_at_risk", content: content, trigger: trigger))
    }

    public func scheduleAppsUnlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Apps unlocked 🎉"
        content.body = "You met today's goal. Enjoy your evening — see you tomorrow."
        center.add(UNNotificationRequest(identifier: "apps_unlocked_\(UUID().uuidString)", content: content, trigger: nil))
    }

    public func scheduleReadPromptFromShield() {
        let content = UNMutableNotificationContent()
        content.title = "Ready to read?"
        content.body = "Tap to open today's pages and unlock your apps."
        content.userInfo = ["deepLink": "iqralock://read"]
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        center.add(UNNotificationRequest(identifier: "shield_read_prompt", content: content, trigger: trigger))
        AppGroupStore.shared.pendingDeepLink = "iqralock://read"
    }
}
