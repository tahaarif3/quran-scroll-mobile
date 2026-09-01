import XCTest
@testable import IqraLockKit

final class PrayerTimeAdjustmentsTests: XCTestCase {
    func testOffsetShiftsResolvedTime() {
        let base = PrayerTimesCalculator.compute(latitude: 33.749, longitude: -84.388)
        var adjustments = PrayerTimeAdjustments.none
        adjustments.setOffset(7, for: .dhuhr)

        let resolved = PrayerTimesResolver.resolve(
            latitude: 33.749,
            longitude: -84.388,
            adjustments: adjustments
        )

        let delta = resolved.dhuhr.timeIntervalSince(base.dhuhr)
        XCTAssertEqual(delta, 7 * 60, accuracy: 1)
    }

    func testOffsetMathFromPickedTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 13, minute: 37))!
        let picked = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 13, minute: 42))!

        let offset = PrayerTimeOffsetMath.offsetMinutes(from: day, to: picked, calendar: calendar)
        XCTAssertEqual(offset, 5)
    }

    func testSettingsRoundTripThroughAppGroup() {
        let store = AppGroupStore(suiteName: "test.prayer.adjust.\(UUID().uuidString)")
        var adjustments = PrayerTimeAdjustments.none
        adjustments.setOffset(-3, for: .fajr)
        adjustments.setOffset(10, for: .isha)

        PrayerTimeSettings.save(adjustments, profile: nil, store: store)
        let loaded = PrayerTimeSettings.load(profile: nil, store: store)

        XCTAssertEqual(loaded.offset(for: .fajr), -3)
        XCTAssertEqual(loaded.offset(for: .isha), 10)
        XCTAssertFalse(loaded.isAdjusted(.dhuhr))
    }

    func testResetClearsOffsets() {
        var adjustments = PrayerTimeAdjustments.none
        adjustments.setOffset(5, for: .asr)
        adjustments.resetAll()
        XCTAssertFalse(adjustments.hasAny)
    }

    func testNotificationsUseAdjustedTimes() {
        var adjustments = PrayerTimeAdjustments.none
        adjustments.setOffset(15, for: .maghrib)

        let base = PrayerTimesResolver.resolve(latitude: 33.749, longitude: -84.388, adjustments: .none)
        let adjusted = PrayerTimesResolver.resolve(
            latitude: 33.749,
            longitude: -84.388,
            adjustments: adjustments
        )

        XCTAssertEqual(
            adjusted.maghrib.timeIntervalSince(base.maghrib),
            15 * 60,
            accuracy: 1
        )
    }
}
