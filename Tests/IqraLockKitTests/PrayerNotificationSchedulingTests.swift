import XCTest
@testable import IqraLockKit

final class PrayerNotificationSchedulingTests: XCTestCase {
    private let scheduler = LocalNotificationScheduler()

    func testPrayerNotificationSchedulerImplementsProtocol() {
        let type: NotificationScheduling.Type = LocalNotificationScheduler.self
        XCTAssertNotNil(type)
        _ = scheduler
    }

    func testPrayerTimesUsedForNotificationScheduling() {
        let times = PrayerTimesCalculator.compute(latitude: 33.749, longitude: -84.388)
        XCTAssertEqual(times.ordered.count, PrayerName.allCases.count)
        for (prayer, date) in times.ordered {
            XCTAssertFalse(prayer.displayName.isEmpty)
            XCTAssertGreaterThan(date.timeIntervalSince1970, 0)
        }
    }
}
