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

    func testChangingAllowancePreservesBreaksAlreadyUsedThisMonth() {
        let store = makeStore()
        store.resetBathroomBreaksIfNeeded(monthlyAllowance: 5)
        store.bathroomBreaksRemaining = 3

        store.updateBathroomBreakMonthlyAllowance(8)
        XCTAssertEqual(store.bathroomBreakMonthlyAllowance, 8)
        XCTAssertEqual(store.bathroomBreaksRemaining, 6)

        store.updateBathroomBreakMonthlyAllowance(3)
        XCTAssertEqual(store.bathroomBreaksRemaining, 1)
    }

    func testConfiguredAllowanceRefillsAtTheNextMonth() {
        let store = makeStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let january = Date(timeIntervalSince1970: 1_767_225_600)
        let february = Date(timeIntervalSince1970: 1_769_904_000)
        store.bathroomBreakMonthlyAllowance = 7

        store.resetBathroomBreaksIfNeeded(now: january, calendar: calendar)
        XCTAssertEqual(store.bathroomBreaksRemaining, 7)
        store.bathroomBreaksRemaining = 1

        store.resetBathroomBreaksIfNeeded(now: february, calendar: calendar)
        XCTAssertEqual(store.bathroomBreaksRemaining, 7)
    }
}
