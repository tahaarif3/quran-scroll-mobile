import XCTest
@testable import IqraLockKit

/// End-to-end style tests for the progress/streak pipeline without SwiftData.
final class ProgressIntegrationTests: XCTestCase {
    func testReadingTodayUpdatesStreakWhenGoalMet() {
        let store = AppGroupStore(suiteName: "test.progress.\(UUID().uuidString)")
        store.ensureCurrentDay()
        store.dailyGoalAyahs = 1
        store.ayahsPerPage = 10

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = HabitStatsCalculator.DayInput(
            day: yesterday, pagesRead: 1, minutesRead: 10, goalMet: true
        )

        store.recordAyah(confirmed: true)
        // Simulate yesterday + today merged
        let merged = DailyProgressSync.recordsIncludingToday(stored: [], store: store)
        var withYesterday = [yesterdayRecord] + merged
        let stats = HabitStatsCalculator.compute(records: withYesterday)

        XCTAssertTrue(store.goalMetToday)
        XCTAssertEqual(stats.streakDays, 2, "yesterday + today both goal-met should be a 2-day streak")
        XCTAssertGreaterThan(stats.minutesLast7Days[6], 0)
    }

    func testStreakAtRiskNotificationScheduledWhenGoalUnmet() {
        let store = AppGroupStore(suiteName: "test.streakrisk.\(UUID().uuidString)")
        store.ensureCurrentDay()
        store.dailyGoalAyahs = 10
        let notifications = NotificationTestDouble()
        let unlock = UnlockCoordinator(
            store: store,
            notifications: notifications
        )

        _ = unlock.recordAyahRead(confirmed: true)
        // Simulate bootstrap scheduling
        notifications.scheduleStreakAtRiskIfNeeded(goalMet: store.goalMetToday)

        XCTAssertTrue(notifications.streakAtRiskScheduled)
    }

    func testWeekdayLabelsMatchSevenDayWindow() {
        let labels = DailyProgressSync.weekdayLabels()
        XCTAssertEqual(labels.count, 7)
        XCTAssertFalse(labels.contains(where: { $0.isEmpty }))
    }
}
