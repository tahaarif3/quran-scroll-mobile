import Foundation
@testable import IqraLockKit

/// Shared no-op notification scheduler for unit tests.
final class NotificationTestDouble: NotificationScheduling, @unchecked Sendable {
    var streakAtRiskScheduled = false
    var prayerNotificationsScheduled = false
    var prayerNotificationsCancelled = false

    func requestPermission() async -> Bool { true }
    func scheduleDailyReminder(hour: Int, minute: Int) {}
    func scheduleStreakAtRiskIfNeeded(goalMet: Bool) {
        streakAtRiskScheduled = !goalMet
    }
    func scheduleAppsUnlocked() {}
    func scheduleReadPromptFromShield() {}
    func schedulePrayerNotifications(latitude: Double, longitude: Double) {
        prayerNotificationsScheduled = true
    }
    func cancelPrayerNotifications() {
        prayerNotificationsCancelled = true
    }
}
