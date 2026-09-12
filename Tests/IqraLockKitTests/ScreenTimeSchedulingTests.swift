import XCTest
@testable import IqraLockKit

final class ScreenTimeSchedulingTests: XCTestCase {
    func testFiveMinuteUnlockUsesValidFifteenMinuteMonitoringWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deadline = now.addingTimeInterval(5 * 60)

        let window = ReshieldScheduleWindow(now: now, unlockUntil: deadline)

        XCTAssertEqual(window.end, deadline)
        XCTAssertEqual(window.end.timeIntervalSince(window.start), 15 * 60)
        XCTAssertLessThan(window.start, now)
    }

    func testLongUnlockStartsNowAndKeepsRequestedDeadline() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deadline = now.addingTimeInterval(30 * 60)

        let window = ReshieldScheduleWindow(now: now, unlockUntil: deadline)

        XCTAssertEqual(window.start, now)
        XCTAssertEqual(window.end, deadline)
    }

    func testScheduleComponentsIncludeCalendarDateAcrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 12, hour: 23, minute: 58
        ))!
        let deadline = calendar.date(byAdding: .minute, value: 5, to: now)!
        let window = ReshieldScheduleWindow(now: now, unlockUntil: deadline)

        let end = window.components(for: window.end, calendar: calendar)

        XCTAssertEqual(end.year, 2026)
        XCTAssertEqual(end.month, 9)
        XCTAssertEqual(end.day, 13)
        XCTAssertEqual(end.hour, 0)
        XCTAssertEqual(end.minute, 3)
    }
}
