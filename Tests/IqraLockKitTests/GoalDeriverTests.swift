import XCTest
@testable import IqraLockKit

final class GoalDeriverTests: XCTestCase {
    func testBaselineIsThree() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .notYet, readFrequency: .rarely),
            2 // rarely floors down from 3
        )
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .some, readFrequency: .days1to2),
            3
        )
    }

    func testFrequencyBoost() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .some, readFrequency: .everyDay),
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
            GoalDeriver.dailyGoalPages(
                arabicAbility: .fluent,
                readFrequency: .everyDay,
                goals: [.completeKhatm]
            ),
            5
        )
    }

    func testFloorTwo() {
        XCTAssertEqual(
            GoalDeriver.dailyGoalPages(arabicAbility: .notYet, readFrequency: .rarely, goals: []),
            2
        )
    }
}
