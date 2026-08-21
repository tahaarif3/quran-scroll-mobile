import XCTest
@testable import IqraLockKit

final class EntitlementGateTests: XCTestCase {
    /// Nothing is withheld from anyone. These assertions used to say the opposite — blocking and
    /// stats required Pro — which described the gate but not the app: `ShieldCoordinator` never
    /// consulted `canBlockApps`, so blocking always worked for everyone and the only thing the
    /// gate produced was copy telling free users they lacked something they had.
    func testEveryFeatureIsAvailableWithoutPro() {
        let free = EntitlementGate(hasPro: false)
        XCTAssertTrue(free.canReadQuran)
        XCTAssertTrue(free.canBlockApps)
        XCTAssertTrue(free.canSeeStats)
        XCTAssertTrue(free.canUseReaderThemes)
        XCTAssertTrue(free.canUseWidgets)
        XCTAssertEqual(free.maxTranslations, 20)
        XCTAssertEqual(free.maxEmergencyPasses, 5)
    }

    /// Subscribing must not take anything away either, and must not quietly become the only way
    /// to get something back.
    func testSubscribingChangesNoEntitlement() {
        let free = EntitlementGate(hasPro: false)
        let supporter = EntitlementGate(hasPro: true)
        XCTAssertEqual(free.canReadQuran, supporter.canReadQuran)
        XCTAssertEqual(free.canBlockApps, supporter.canBlockApps)
        XCTAssertEqual(free.canSeeStats, supporter.canSeeStats)
        XCTAssertEqual(free.canUseReaderThemes, supporter.canUseReaderThemes)
        XCTAssertEqual(free.canUseWidgets, supporter.canUseWidgets)
        XCTAssertEqual(free.maxTranslations, supporter.maxTranslations)
        XCTAssertEqual(free.maxEmergencyPasses, supporter.maxEmergencyPasses)
    }
}
