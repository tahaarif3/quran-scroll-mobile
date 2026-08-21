import XCTest
@testable import IqraLockKit

final class EntitlementGateTests: XCTestCase {
    /// Pro exists as a tier but has no features of its own yet, so nothing is withheld today.
    /// These assertions used to say the opposite — blocking and stats required Pro — which
    /// described the gate but not the app: `ShieldCoordinator` never consulted `canBlockApps`,
    /// so blocking always worked for everyone and the flags produced nothing but copy telling
    /// free users they lacked what they had.
    ///
    /// When a real Pro feature lands, its flag returns `hasPro` and this test changes with it.
    /// Until then these are the guard against re-introducing a paywall the app does not honour.
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

    /// Whatever ships as Pro later, subscribing must never take away something that was free —
    /// this asserts parity for the features that exist today, not for all time.
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
