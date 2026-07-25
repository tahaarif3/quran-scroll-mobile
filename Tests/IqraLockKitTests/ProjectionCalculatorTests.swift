import XCTest
@testable import IqraLockKit

final class ProjectionCalculatorTests: XCTestCase {
    func testOver8ProducesHighYearsLost() {
        let result = ProjectionCalculator.project(screenTime: .over8, age: .age25to34)
        XCTAssertGreaterThanOrEqual(result.yearsLost, 15)
        XCTAssertEqual(result.quranDays, 30)
    }

    func testUnder2IsMuchLowerThanOver8() {
        let low = ProjectionCalculator.project(screenTime: .under2, age: .age25to34)
        let high = ProjectionCalculator.project(screenTime: .over8, age: .age25to34)
        XCTAssertLessThan(low.yearsLost, high.yearsLost)
        XCTAssertEqual(low.quranDays, 60)
    }

    func testYearsBackIsPositivePortionOfLost() {
        let result = ProjectionCalculator.project(screenTime: .hours4to8, age: .age18to24)
        XCTAssertGreaterThan(result.yearsBackToDeen, 0)
        XCTAssertLessThanOrEqual(result.yearsBackToDeen, result.yearsLost)
    }
}
