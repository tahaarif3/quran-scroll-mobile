import XCTest
@testable import IqraLockKit

final class PrayerLogTests: XCTestCase {
    func testPrayerLogStoresCompletedSalah() {
        let log = PrayerLog(day: Date())
        XCTAssertTrue(log.completed.isEmpty)
        log.completed.append(PrayerName.fajr.rawValue)
        log.completed.append(PrayerName.maghrib.rawValue)
        XCTAssertEqual(log.completed.count, 2)
        XCTAssertTrue(log.completed.contains("fajr"))
    }

    func testPrayerLogNormalizesDayToStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
        let log = PrayerLog(day: afternoon)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: log.day),
            Calendar.current.startOfDay(for: afternoon)
        )
    }
}
