import XCTest
@testable import IqraLockKit

final class PrayerTimesCalculatorTests: XCTestCase {
  func testProducesAllFivePrayers() {
    let times = PrayerTimesCalculator.compute(latitude: 33.749, longitude: -84.388)
    XCTAssertEqual(times.ordered.count, 5)
    XCTAssertEqual(PrayerName.allCases.count, 5)
  }

  func testTimesFallOnSameCalendarDay() {
    let tz = TimeZone(identifier: "America/New_York")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    let reference = calendar.startOfDay(for: Date())

    let times = PrayerTimesCalculator.compute(
      date: reference,
      latitude: 33.749,
      longitude: -84.388,
      timeZone: tz
    )

    for (_, time) in times.ordered {
      XCTAssertTrue(calendar.isDate(time, inSameDayAs: reference))
    }
  }

  func testNextPrayerReturnsFutureSalahWhenBeforeIsha() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    let times = PrayerTimesCalculator.compute(
      date: morning,
      latitude: 33.749,
      longitude: -84.388,
      timeZone: calendar.timeZone
    )

    let next = times.nextPrayer(after: morning)
    XCTAssertNotNil(next)
  }
}
