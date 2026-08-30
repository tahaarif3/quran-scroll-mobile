import XCTest
@testable import IqraLockKit

final class PINStoreTests: XCTestCase {
    override func tearDown() {
        PINStore.delete()
        super.tearDown()
    }

    func testSaveVerifyAndDelete() {
        XCTAssertFalse(PINStore.isConfigured)
        XCTAssertTrue(PINStore.save(pin: "1234"))
        XCTAssertTrue(PINStore.isConfigured)
        XCTAssertTrue(PINStore.verify(pin: "1234"))
        XCTAssertFalse(PINStore.verify(pin: "0000"))

        PINStore.delete()
        XCTAssertFalse(PINStore.isConfigured)
        XCTAssertFalse(PINStore.verify(pin: "1234"))
    }

    func testRejectsShortPIN() {
        XCTAssertFalse(PINStore.save(pin: "12"))
        XCTAssertFalse(PINStore.isConfigured)
    }

    func testOverwriteReplacesPreviousPIN() {
        XCTAssertTrue(PINStore.save(pin: "1111"))
        XCTAssertTrue(PINStore.save(pin: "2222"))
        XCTAssertFalse(PINStore.verify(pin: "1111"))
        XCTAssertTrue(PINStore.verify(pin: "2222"))
    }
}
