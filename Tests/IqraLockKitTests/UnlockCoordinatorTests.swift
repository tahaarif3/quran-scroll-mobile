import XCTest
@testable import IqraLockKit

final class UnlockCoordinatorTests: XCTestCase {
    func testUnlocksWhenGoalMet() {
        let store = AppGroupStore(suiteName: "test.unlock.\(UUID().uuidString)")
        // Seed the day key first. On a fresh suite `dayKey` is "", so the `ensureCurrentDay()`
        // inside `evaluateAfterPageMarked()` would treat this as a day rollover and reset
        // `pagesReadToday` to 0 — discarding the state under test.
        store.ensureCurrentDay()
        store.dailyGoalPages = 3
        store.pagesReadToday = 2
        store.isLockedNow = true
        let screenTime = MockScreenTimeService(store: store)
        screenTime.applyShield()
        let shield = ShieldCoordinator(store: store, screenTime: screenTime)
        let unlock = UnlockCoordinator(store: store, shield: shield, notifications: NoopNotifications())

        store.pagesReadToday = 3
        let met = unlock.evaluateAfterPageMarked()
        XCTAssertTrue(met)
        XCTAssertFalse(store.isLockedNow)
        XCTAssertFalse(screenTime.isShielded)
    }

    func testDoesNotUnlockBeforeGoal() {
        let store = AppGroupStore(suiteName: "test.unlock2.\(UUID().uuidString)")
        // Also seeded: without this the assertions below pass for the wrong reason — the
        // day-rollover reset zeroes the page count and re-locks, which happens to match.
        store.ensureCurrentDay()
        store.dailyGoalPages = 5
        store.pagesReadToday = 2
        store.isLockedNow = true
        let screenTime = MockScreenTimeService(store: store)
        let unlock = UnlockCoordinator(
            store: store,
            shield: ShieldCoordinator(store: store, screenTime: screenTime),
            notifications: NoopNotifications()
        )
        XCTAssertFalse(unlock.evaluateAfterPageMarked())
        XCTAssertTrue(store.isLockedNow)
    }

    /// `recordPageRead` owns day-roll + increment + evaluation, so a page can never be
    /// credited and then zeroed by a rollover firing between the two.
    func testRecordPageReadCreditsThePageAndUnlocksOnTheFinalPage() {
        let store = AppGroupStore(suiteName: "test.unlock3.\(UUID().uuidString)")
        store.ensureCurrentDay()
        store.dailyGoalPages = 2
        store.pagesReadToday = 0
        store.isLockedNow = true
        let screenTime = MockScreenTimeService(store: store)
        screenTime.applyShield()
        let unlock = UnlockCoordinator(
            store: store,
            shield: ShieldCoordinator(store: store, screenTime: screenTime),
            notifications: NoopNotifications()
        )

        let first = unlock.recordPageRead()
        XCTAssertEqual(first.pagesToday, 1)
        XCTAssertFalse(first.goalMet)
        XCTAssertTrue(store.isLockedNow, "still locked one page short of the goal")

        let second = unlock.recordPageRead()
        XCTAssertEqual(second.pagesToday, 2)
        XCTAssertTrue(second.goalMet)
        XCTAssertFalse(store.isLockedNow)
        XCTAssertFalse(screenTime.isShielded)
    }

    /// A page marked after the day has rolled counts toward the NEW day rather than being
    /// discarded — the semantic chosen for the midnight edge.
    func testPageMarkedAfterRolloverCountsTowardTheNewDay() {
        let store = AppGroupStore(suiteName: "test.unlock4.\(UUID().uuidString)")
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        store.ensureCurrentDay(now: yesterday)
        store.dailyGoalPages = 3
        store.pagesReadToday = 2

        let screenTime = MockScreenTimeService(store: store)
        let unlock = UnlockCoordinator(
            store: store,
            shield: ShieldCoordinator(store: store, screenTime: screenTime),
            notifications: NoopNotifications()
        )

        // Now it is "today": the day rolls, yesterday's 2 pages are cleared, and this page
        // becomes page 1 of the new day rather than page 3 of the old one.
        let outcome = unlock.recordPageRead()
        XCTAssertEqual(outcome.pagesToday, 1, "the page is credited, not swallowed by the rollover")
        XCTAssertFalse(outcome.goalMet)
    }
}

private final class NoopNotifications: NotificationScheduling, @unchecked Sendable {
    func requestPermission() async -> Bool { true }
    func scheduleDailyReminder(hour: Int, minute: Int) {}
    func scheduleStreakAtRiskIfNeeded(goalMet: Bool) {}
    func scheduleAppsUnlocked() {}
    func scheduleReadPromptFromShield() {}
}
