import XCTest
@testable import IqraLockKit

final class EntitlementGateTests: XCTestCase {
    func testReaderAlwaysFree() {
        XCTAssertTrue(EntitlementGate(hasPro: false).canReadQuran)
        XCTAssertTrue(EntitlementGate(hasPro: true).canReadQuran)
    }

    func testBlockingRequiresPro() {
        XCTAssertFalse(EntitlementGate(hasPro: false).canBlockApps)
        XCTAssertTrue(EntitlementGate(hasPro: true).canBlockApps)
    }

    func testStatsRequirePro() {
        let free = EntitlementGate(hasPro: false)
        let pro = EntitlementGate(hasPro: true)
        XCTAssertFalse(free.canSeeStats)
        XCTAssertTrue(pro.canSeeStats)
        XCTAssertEqual(free.maxTranslations, 1)
        XCTAssertEqual(pro.maxTranslations, 20)
    }
}
