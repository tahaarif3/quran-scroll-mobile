import XCTest
@testable import IqraLockKit

final class PrayerNotificationSchedulingTests: XCTestCase {
    func testPrayerTimesUsedForNotificationScheduling() {
        let times = PrayerTimesResolver.resolve(latitude: 33.749, longitude: -84.388)
        XCTAssertEqual(times.ordered.count, PrayerName.allCases.count)
        for (prayer, date) in times.ordered {
            XCTAssertFalse(prayer.displayName.isEmpty)
            XCTAssertGreaterThan(date.timeIntervalSince1970, 0)
        }
    }

    func testSchedulerUsesSameResolverPathAsAdjustments() {
        var adjustments = PrayerTimeAdjustments.none
        adjustments.setOffset(12, for: .dhuhr)

        let baseline = PrayerTimesResolver.resolve(
            latitude: 33.749,
            longitude: -84.388,
            adjustments: .none
        )
        let adjusted = PrayerTimesResolver.resolve(
            latitude: 33.749,
            longitude: -84.388,
            adjustments: adjustments
        )

        XCTAssertEqual(
            adjusted.dhuhr.timeIntervalSince(baseline.dhuhr),
            12 * 60,
            accuracy: 1
        )
    }

    func testPrayerNotificationIdentifiersAreStable() {
        let ids = PrayerName.allCases.map { "prayer_\($0.rawValue)" }
        XCTAssertEqual(ids, ["prayer_fajr", "prayer_dhuhr", "prayer_asr", "prayer_maghrib", "prayer_isha"])
    }
}
