import XCTest
@testable import IqraLockKit

final class ReaderResumeTests: XCTestCase {
    func testResumeFallsBackToKhatmCursorWhenUnset() {
        let store = AppGroupStore(suiteName: "test.resume.\(UUID().uuidString)")
        store.khatmCursor = 120
        XCTAssertEqual(ReaderResume.resumeGlobalID(store: store), 120)
    }

    func testResumeUsesStoredPosition() {
        let store = AppGroupStore(suiteName: "test.resume.\(UUID().uuidString)")
        store.khatmCursor = 496
        store.readerResumeGlobalID = 842
        XCTAssertEqual(ReaderResume.resumeGlobalID(store: store), 842)
    }

    func testSyncResumePullsForwardWhenShieldAdvancesKhatm() {
        let store = AppGroupStore(suiteName: "test.resume.\(UUID().uuidString)")
        store.readerResumeGlobalID = 100
        store.khatmCursor = 150
        ReaderResume.syncResumeFromKhatmIfNeeded(store: store)
        XCTAssertEqual(store.readerResumeGlobalID, 150)
    }

    func testSyncResumeDoesNotMoveBackward() {
        let store = AppGroupStore(suiteName: "test.resume.\(UUID().uuidString)")
        store.readerResumeGlobalID = 500
        store.khatmCursor = 120
        ReaderResume.syncResumeFromKhatmIfNeeded(store: store)
        XCTAssertEqual(ReaderResume.resumeGlobalID(store: store), 500)
    }

    func testSaveClampsToMushafBounds() {
        let store = AppGroupStore(suiteName: "test.resume.\(UUID().uuidString)")
        ReaderResume.save(globalID: 999_999, store: store)
        XCTAssertEqual(store.readerResumeGlobalID, 0)
        ReaderResume.save(globalID: 42, store: store)
        XCTAssertEqual(store.readerResumeGlobalID, 42)
    }
}
