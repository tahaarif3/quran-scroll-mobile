import XCTest
@testable import IqraLockKit

final class UnlockCoordinatorTests: XCTestCase {
    func testUnlocksWhenGoalMet() {
        let store = AppGroupStore(suiteName: "test.unlock.\(UUID().uuidString)")
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
}

private final class NoopNotifications: NotificationScheduling, @unchecked Sendable {
    func requestPermission() async -> Bool { true }
    func scheduleDailyReminder(hour: Int, minute: Int) {}
    func scheduleStreakAtRiskIfNeeded(goalMet: Bool) {}
    func scheduleAppsUnlocked() {}
    func scheduleReadPromptFromShield() {}
}
