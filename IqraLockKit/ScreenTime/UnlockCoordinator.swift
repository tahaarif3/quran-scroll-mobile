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

    /// Record one page as read and decide whether that meets today's goal.
    ///
    /// Day-roll, increment and evaluation happen here together, in that order, so a page is
    /// always credited to whichever day is current at the moment it is marked — a page marked
    /// at 00:00:01 counts toward the new day and begins building that day's goal. Callers must
    /// not increment `pagesReadToday` themselves: doing so leaves a window in which
    /// `ensureCurrentDay` can roll the day between the increment and the evaluation and zero
    /// the page that was just read.
    ///
    /// - Returns: the day's page count after recording, and whether the goal is now met.
    @discardableResult
    public func recordPageRead(now: Date = Date()) -> (pagesToday: Int, goalMet: Bool) {
        store.ensureCurrentDay(now: now)
        store.pagesReadToday += 1
        let met = evaluate(now: now)
        return (store.pagesReadToday, met)
    }

    /// Evaluate the current counters without recording a page. Safe to call repeatedly.
    @discardableResult
    public func evaluateAfterPageMarked(now: Date = Date()) -> Bool {
        store.ensureCurrentDay(now: now)
        return evaluate(now: now)
    }

    private func evaluate(now: Date) -> Bool {
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
