import XCTest
@testable import IqraLockKit

final class PINStoreTests: XCTestCase {
    func testFamilyPINSessionUnlockLastsUntilSessionIsLocked() {
        let session = FamilyPINSession()

        XCTAssertTrue(session.allowsSettingsChanges(pinConfigured: false))
        XCTAssertFalse(session.allowsSettingsChanges(pinConfigured: true))

        session.unlock()
        XCTAssertTrue(session.allowsSettingsChanges(pinConfigured: true))

        session.lock()
        XCTAssertFalse(session.allowsSettingsChanges(pinConfigured: true))
    }

    override func tearDown() {
        PINStore.delete()
        super.tearDown()
    }

    private func requireKeychain() throws {
        guard PINStore.save(pin: "9999") else {
            throw XCTSkip("Keychain unavailable in this test environment")
        }
        PINStore.delete()
    }

    func testSaveVerifyAndDelete() throws {
        try requireKeychain()
        XCTAssertFalse(PINStore.isConfigured)
        XCTAssertTrue(PINStore.save(pin: "1234"))
        XCTAssertTrue(PINStore.isConfigured)
        XCTAssertTrue(PINStore.verify(pin: "1234"))
        XCTAssertFalse(PINStore.verify(pin: "0000"))

        PINStore.delete()
        XCTAssertFalse(PINStore.isConfigured)
        XCTAssertFalse(PINStore.verify(pin: "1234"))
    }

    func testRejectsShortPIN() throws {
        try requireKeychain()
        XCTAssertFalse(PINStore.save(pin: "12"))
        XCTAssertFalse(PINStore.isConfigured)
    }

    func testOverwriteReplacesPreviousPIN() throws {
        try requireKeychain()
        XCTAssertTrue(PINStore.save(pin: "1111"))
        XCTAssertTrue(PINStore.save(pin: "2222"))
        XCTAssertFalse(PINStore.verify(pin: "1111"))
        XCTAssertTrue(PINStore.verify(pin: "2222"))
    }
}
