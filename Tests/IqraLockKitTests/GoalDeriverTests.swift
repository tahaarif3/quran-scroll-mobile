import XCTest
@testable import IqraLockKit

final class GoalDeriverTests: XCTestCase {
    func testBaselineIsThree() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .soundOut, readFrequency: .days1to2),
            3
        )
    }

    func testFrequencyBoost() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .soundOut, readFrequency: .everyDay),
            4
        )
    }

    func testArabicBoost() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .fluent, readFrequency: .days1to2),
            4
        )
    }

    func testBothBoostsCapAtFive() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .fluent, readFrequency: .everyDay),
            5
        )
    }

    func testRareReadingFloorsToTwo() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .learningLetters, readFrequency: .lessThanWeekly),
            2
        )
    }
}
