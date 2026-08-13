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

    public struct AyahOutcome: Equatable, Sendable {
        /// False when the tap arrived too soon after the last one to be a real reading.
        public let counted: Bool
        public let ayahsIntoPage: Int
        public let ayahsPerPage: Int
        public let pagesToday: Int
        public let goalMet: Bool
    }

    /// Minimum gap between two ayahs that both count.
    ///
    /// The shield's read button is one tap, so without this the whole day's goal is a few
    /// seconds of tapping and the app's central claim is worthless. Deliberately lenient — it
    /// is meant to stop reflex tapping, not to police a fast reader.
    public static let minimumAyahInterval: TimeInterval = 5

    /// Record a single ayah. Ten of them — `ayahsPerPage` — roll into a page.
    ///
    /// This is the small-progress path: a user who reads one ayah off the shield has moved
    /// forward, rather than facing an all-or-nothing page. Rolling into pages rather than
    /// replacing them keeps the goal, the streak and the khatm count denominated in something
    /// that means something.
    @discardableResult
    public func recordAyahRead(now: Date = Date()) -> AyahOutcome {
        store.ensureCurrentDay(now: now)

        if let last = store.lastAyahReadAt,
           now.timeIntervalSince(last) < Self.minimumAyahInterval {
            analytics.track("ayah_read_rejected_too_fast", properties: [:])
            return AyahOutcome(
                counted: false,
                ayahsIntoPage: store.ayahsReadToday,
                ayahsPerPage: store.ayahsPerPage,
                pagesToday: store.pagesReadToday,
                goalMet: store.goalMetToday
            )
        }
        store.lastAyahReadAt = now

        store.ayahsReadToday += 1
        var met = false
        if store.ayahsReadToday >= store.ayahsPerPage {
            store.ayahsReadToday -= store.ayahsPerPage
            store.pagesReadToday += 1
            met = evaluate(now: now)
        } else {
            analytics.track("ayah_read", properties: [
                "ayahsIntoPage": store.ayahsReadToday,
                "ayahsPerPage": store.ayahsPerPage
            ])
            met = store.goalMetToday
        }

        return AyahOutcome(
            counted: true,
            ayahsIntoPage: store.ayahsReadToday,
            ayahsPerPage: store.ayahsPerPage,
            pagesToday: store.pagesReadToday,
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
