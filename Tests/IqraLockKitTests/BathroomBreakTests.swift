import XCTest
@testable import IqraLockKit

final class BathroomBreakTests: XCTestCase {
    private func makeStore() -> AppGroupStore {
        AppGroupStore(suiteName: "test.bathroom.\(UUID().uuidString)")
    }

    func testMonthlyAllowanceIsFive() {
        let store = makeStore()
        store.resetBathroomBreaksIfNeeded(monthlyAllowance: 5)
        XCTAssertEqual(store.bathroomBreaksRemaining, 5)
    }

    func testConsumingBreakDecrementsRemaining() {
        let store = makeStore()
        store.resetBathroomBreaksIfNeeded(monthlyAllowance: 5)
        let screenTime = MockScreenTimeService(store: store)

        XCTAssertTrue(screenTime.consumeBathroomBreak(durationMinutes: 5))
        XCTAssertEqual(store.bathroomBreaksRemaining, 4)
        XCTAssertFalse(screenTime.isShielded)
        XCTAssertNotNil(store.unlockedUntil)
    }

    func testCannotConsumeWhenExhausted() {
        let store = makeStore()
        store.resetBathroomBreaksIfNeeded(monthlyAllowance: 5)
        let screenTime = MockScreenTimeService(store: store)
        store.bathroomBreaksRemaining = 0

        XCTAssertFalse(screenTime.consumeBathroomBreak())
        XCTAssertEqual(store.bathroomBreaksRemaining, 0)
    }

    func testMigratesLegacyEmergencyPassKeys() {
        let suite = "test.migrate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(2, forKey: "emergencyPassesRemaining")
        defaults.set("2026-8", forKey: "emergencyPassesMonthKey")

        let store = AppGroupStore(suiteName: suite)
        XCTAssertEqual(store.bathroomBreaksRemaining, 2)
    }

    func testEmergencyPassAliasDelegatesToBathroomBreak() {
        let store = makeStore()
        store.bathroomBreaksRemaining = 3
        XCTAssertEqual(store.emergencyPassesRemaining, 3)
        store.emergencyPassesRemaining = 1
        XCTAssertEqual(store.bathroomBreaksRemaining, 1)
    }
}
