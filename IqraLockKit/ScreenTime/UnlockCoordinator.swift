import Foundation

public final class UnlockCoordinator: @unchecked Sendable {
    private let store: AppGroupStore
    private let shield: ShieldCoordinator
    private let analytics: AnalyticsService
    private let notifications: NotificationScheduling

    public init(
        store: AppGroupStore = .shared,
        shield: ShieldCoordinator? = nil,
        analytics: AnalyticsService = NoopAnalytics(),
        notifications: NotificationScheduling = LocalNotificationScheduler()
    ) {
        self.store = store
        self.shield = shield ?? ShieldCoordinator(store: store)
        self.analytics = analytics
        self.notifications = notifications
    }

    /// Call after marking a page read. Unlocks when goal is met.
    @discardableResult
    public func evaluateAfterPageMarked(now: Date = Date()) -> Bool {
        store.ensureCurrentDay(now: now)
        analytics.track("page_marked_read", properties: [
            "pages": store.pagesReadToday,
            "goal": store.dailyGoalPages
        ])
        guard store.goalMetToday else { return false }
        shield.unlockForRestOfDay(now: now)
        analytics.track("daily_goal_met", properties: [
            "pages": store.pagesReadToday
        ])
        notifications.scheduleAppsUnlocked()
        return true
    }
}
