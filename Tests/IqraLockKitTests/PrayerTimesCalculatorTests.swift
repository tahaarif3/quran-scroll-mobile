import XCTest
@testable import IqraLockKit

final class PrayerTimesCalculatorTests: XCTestCase {
    /// Atlanta, GA — sanity check that prayer times are ordered and on the same day.
    func testPrayerTimesAreChronological() {
        let times = PrayerTimesCalculator.compute(
            latitude: 33.749,
            longitude: -84.388,
            timeZone: TimeZone(identifier: "America/New_York")!
        )

        XCTAssertLessThan(times.fajr, times.dhuhr)
        XCTAssertLessThan(times.dhuhr, times.asr)
        XCTAssertLessThan(times.asr, times.maghrib)
        XCTAssertLessThan(times.maghrib, times.isha)
    }

    func testNextPrayerReturnsFutureSalah() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

        let times = PrayerTimesCalculator.compute(
            date: noon,
            latitude: 33.749,
            longitude: -84.388,
            timeZone: calendar.timeZone
        )

        let next = times.nextPrayer(after: noon)
        XCTAssertNotNil(next)
        XCTAssertTrue(next!.1 > noon)
    }

    func testAllFivePrayersPresent() {
        let times = PrayerTimesCalculator.compute(latitude: 21.4225, longitude: 39.8262)
        XCTAssertEqual(times.ordered.count, 5)
        XCTAssertEqual(PrayerName.allCases.count, 5)
    }
}
