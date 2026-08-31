import XCTest
@testable import IqraLockKit

final class CasualReadingModeTests: XCTestCase {
    func testCasualModeSkipsScreenTimeEffects() {
        let store = AppGroupStore(suiteName: "test.casual.\(UUID().uuidString)")
        store.ensureCurrentDay()
        store.casualReadingMode = true
        store.dailyGoalAyahs = 10
        store.ayahsPerPage = 10

        let screenTime = MockScreenTimeService(store: store)
        screenTime.applyShield()
        let unlock = UnlockCoordinator(
            store: store,
            shield: ShieldCoordinator(store: store, screenTime: screenTime),
            notifications: NotificationTestDouble()
        )

        let outcome = unlock.recordAyahRead()
        XCTAssertTrue(outcome.counted)
        XCTAssertEqual(store.totalAyahsToday, 0, "casual mode must not credit daily progress")
        XCTAssertTrue(screenTime.isShielded, "casual mode must not clear the shield")
        XCTAssertNil(store.unlockedUntil)
    }

    func testFocusModeCreditsAyahAndGrantsWindow() {
        let store = AppGroupStore(suiteName: "test.focus.\(UUID().uuidString)")
        store.ensureCurrentDay()
        store.casualReadingMode = false
        store.ayahsPerPage = 10

        let screenTime = MockScreenTimeService(store: store)
        screenTime.applyShield()
        let unlock = UnlockCoordinator(
            store: store,
            shield: ShieldCoordinator(store: store, screenTime: screenTime),
            notifications: NotificationTestDouble()
        )

        let outcome = unlock.recordAyahRead(confirmed: true)
        XCTAssertTrue(outcome.counted)
        XCTAssertEqual(store.totalAyahsToday, 1)
        XCTAssertFalse(screenTime.isShielded)
        XCTAssertNotNil(store.unlockedUntil)
    }
}
