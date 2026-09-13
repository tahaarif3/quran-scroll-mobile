import XCTest
@testable import IqraLockKit

final class IqraBuildTests: XCTestCase {
    func testLegalLinksAreHttpsIqraLock() {
        XCTAssertEqual(LegalLinks.privacy.host, "iqralock.app")
        XCTAssertEqual(LegalLinks.privacy.path, "/privacy")
        XCTAssertEqual(LegalLinks.terms.host, "iqralock.app")
        XCTAssertEqual(LegalLinks.terms.path, "/terms")
        XCTAssertEqual(LegalLinks.privacy.scheme, "https")
    }

    func testPurchaseFactoryMatchesBuildFlavor() {
        let service = PurchaseServiceFactory.make()
        #if DEBUG || INTERNAL_TESTFLIGHT
        XCTAssertTrue(service is MockPurchaseService)
        XCTAssertTrue(IqraBuild.usesMockPurchases)
        #else
        XCTAssertTrue(service is StoreKitPurchaseService)
        XCTAssertFalse(IqraBuild.usesMockPurchases)
        #endif
    }
}
