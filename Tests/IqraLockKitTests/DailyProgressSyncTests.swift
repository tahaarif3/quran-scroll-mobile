import XCTest
@testable import IqraLockKit

final class DailyProgressSyncTests: XCTestCase {
    func testRecordsIncludingTodayMergesLiveStore() {
        let store = AppGroupStore(suiteName: "test.dailyprogress.\(UUID().uuidString)")
        store.dailyGoalAyahs = 10
        store.ayahsPerPage = 10
        store.pagesReadToday = 1
        store.ayahsReadToday = 3

        let merged = DailyProgressSync.recordsIncludingToday(stored: [], store: store)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].pagesRead, 1)
        XCTAssertFalse(merged[0].goalMet)
    }

    func testWeekdayLabelsCount() {
        XCTAssertEqual(DailyProgressSync.weekdayLabels().count, 7)
    }
}
