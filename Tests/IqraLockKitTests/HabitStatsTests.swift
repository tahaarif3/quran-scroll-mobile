import XCTest
@testable import IqraLockKit

final class HabitStatsTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    func testStreakCountsConsecutiveGoalMetDaysEndingToday() {
        let today = calendar.startOfDay(for: Date())
        let records = (0..<5).compactMap { offset -> HabitStatsCalculator.DayInput? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return .init(day: day, pagesRead: 3, minutesRead: 10, goalMet: true)
        }
        let stats = HabitStatsCalculator.compute(records: records, now: today, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 5)
    }

    func testStreakBreaksOnGap() {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today) else {
            return XCTFail("dates")
        }
        let records = [
            HabitStatsCalculator.DayInput(day: today, pagesRead: 3, minutesRead: 10, goalMet: true),
            HabitStatsCalculator.DayInput(day: yesterday, pagesRead: 3, minutesRead: 10, goalMet: true),
            HabitStatsCalculator.DayInput(day: threeDaysAgo, pagesRead: 3, minutesRead: 10, goalMet: true)
        ]
        let stats = HabitStatsCalculator.compute(records: records, now: today, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 2)
    }

    func testStreakAllowsYesterdayIfTodayUnmet() {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return XCTFail("dates")
        }
        let records = [
            HabitStatsCalculator.DayInput(day: today, pagesRead: 1, minutesRead: 5, goalMet: false),
            HabitStatsCalculator.DayInput(day: yesterday, pagesRead: 3, minutesRead: 12, goalMet: true)
        ]
        let stats = HabitStatsCalculator.compute(records: records, now: today, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 1)
    }

    func testReadingWithoutGoalDoesNotCountStreak() {
        let today = calendar.startOfDay(for: Date())
        let records = [
            HabitStatsCalculator.DayInput(day: today, pagesRead: 2, minutesRead: 8, goalMet: false)
        ]
        let stats = HabitStatsCalculator.compute(records: records, now: today, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 0)
        XCTAssertEqual(stats.pagesReadTotal, 2)
        XCTAssertEqual(stats.minutesReclaimed, 8)
    }

    func testMinutesLast7DaysWindow() {
        let today = calendar.startOfDay(for: Date())
        guard let twoAgo = calendar.date(byAdding: .day, value: -2, to: today) else {
            return XCTFail("dates")
        }
        let records = [
            HabitStatsCalculator.DayInput(day: today, pagesRead: 1, minutesRead: 15, goalMet: false),
            HabitStatsCalculator.DayInput(day: twoAgo, pagesRead: 1, minutesRead: 30, goalMet: true)
        ]
        let stats = HabitStatsCalculator.compute(records: records, now: today, calendar: calendar)
        XCTAssertEqual(stats.minutesLast7Days.count, 7)
        XCTAssertEqual(stats.minutesLast7Days[6], 15)
        XCTAssertEqual(stats.minutesLast7Days[4], 30)
    }
}
