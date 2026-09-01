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

  func testPrayerTimesAreChronological() {
    let tz = TimeZone(identifier: "America/New_York")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!

    let times = PrayerTimesCalculator.compute(
      date: day,
      latitude: 33.749,
      longitude: -84.388,
      timeZone: tz
    )

    let ordered = times.ordered.map(\.1)
    for index in 1..<ordered.count {
      XCTAssertLessThan(ordered[index - 1], ordered[index])
    }
  }

  func testAtlantaSeptemberTimesAreReasonable() {
    let tz = TimeZone(identifier: "America/New_York")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!

    let times = PrayerTimesCalculator.compute(
      date: day,
      latitude: 33.749,
      longitude: -84.388,
      timeZone: tz
    )

    XCTAssertTrue(hour(times.fajr, calendar: calendar, in: 4...7))
    XCTAssertTrue(hour(times.dhuhr, calendar: calendar, in: 12...14))
    XCTAssertTrue(hour(times.asr, calendar: calendar, in: 15...18))
    XCTAssertTrue(hour(times.maghrib, calendar: calendar, in: 19...21))
    XCTAssertTrue(hour(times.isha, calendar: calendar, in: 20...22))

    // Asr must be afternoon, never AM.
    let asrHour = calendar.component(.hour, from: times.asr)
    XCTAssertGreaterThanOrEqual(asrHour, 12)
  }

  private func hour(_ date: Date, calendar: Calendar, in range: ClosedRange<Int>) -> Bool {
    range.contains(calendar.component(.hour, from: date))
  }
}
