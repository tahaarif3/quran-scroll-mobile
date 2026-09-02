import XCTest
@testable import IqraLockKit

final class PrayerProgressSyncTests: XCTestCase {
    func testLoggedPrayerContributesToStreak() {
        XCTAssertTrue(
            PrayerProgressSync.contributesToStreak(
                readingGoalMet: false,
                prayersLogged: true
            )
        )
    }

    func testOneAyahReadContributesToStreak() {
        XCTAssertTrue(
            PrayerProgressSync.contributesToStreak(
                readingGoalMet: true,
                prayersLogged: false
            )
        )
    }

    func testNeitherReadingNorPrayerDoesNotContribute() {
        XCTAssertFalse(
            PrayerProgressSync.contributesToStreak(
                readingGoalMet: false,
                prayersLogged: false
            )
        )
    }

    func testHasPrayersLoggedOnDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let log = PrayerLog(day: today)
        log.completed = [PrayerName.fajr.rawValue]

        XCTAssertTrue(
            PrayerProgressSync.hasPrayersLogged(on: today, logs: [log], calendar: calendar)
        )
    }

    func testDefaultDailyGoalIsOneAyah() {
        let store = AppGroupStore(suiteName: "test.goal.\(UUID().uuidString)")
        XCTAssertEqual(store.dailyGoalAyahs, 1)
        XCTAssertTrue(store.goalMetToday == false)
        _ = store.recordAyah()
        XCTAssertTrue(store.goalMetToday)
    }

    func testPrayerLogsIncludedInTodayRecords() {
        let store = AppGroupStore(suiteName: "test.prayer.streak.\(UUID().uuidString)")
        let today = Calendar.current.startOfDay(for: Date())
        let log = PrayerLog(day: today)
        log.completed = [PrayerName.dhuhr.rawValue]

        let inputs = DailyProgressSync.recordsIncludingToday(
            stored: [],
            store: store,
            prayerLogs: [log]
        )

        XCTAssertEqual(inputs.count, 1)
        XCTAssertTrue(inputs[0].goalMet)
    }
}
