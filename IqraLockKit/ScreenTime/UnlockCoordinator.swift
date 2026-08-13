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
        store.creditPage()
        let met = evaluate(now: now)
        return (store.pagesReadToday, met)
    }

    public struct AyahOutcome: Equatable, Sendable {
        /// False when the tap arrived too soon after the last one to be a real reading.
        public let counted: Bool
        public let ayahsIntoPage: Int
        public let ayahsPerPage: Int
        public let pagesToday: Int
        public let goalMet: Bool
    }

    /// Record a single ayah. The roll-into-a-page rule lives on the store so the ShieldAction
    /// extension shares it; this adds the analytics and unlock side effects the extension
    /// cannot perform.
    @discardableResult
    public func recordAyahRead(now: Date = Date()) -> AyahOutcome {
        let pagesBefore = store.pagesReadToday
        let record = store.recordAyah(now: now)

        guard record.counted else {
            analytics.track("ayah_read_rejected_too_fast", properties: [:])
            return AyahOutcome(
                counted: false,
                ayahsIntoPage: record.ayahsIntoPage,
                ayahsPerPage: record.ayahsPerPage,
                pagesToday: record.pagesToday,
                goalMet: record.goalMet
            )
        }

        analytics.track("ayah_read", properties: [
            "ayahsIntoPage": record.ayahsIntoPage,
            "ayahsPerPage": record.ayahsPerPage
        ])

        // Only run the unlock path when an ayah actually completed a page, so the notification
        // and shield clearing fire once rather than on every ayah after the goal is met.
        let met = record.pagesToday > pagesBefore ? evaluate(now: now) : record.goalMet
        return AyahOutcome(
            counted: true,
            ayahsIntoPage: record.ayahsIntoPage,
            ayahsPerPage: record.ayahsPerPage,
            pagesToday: record.pagesToday,
            goalMet: met
        )
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
