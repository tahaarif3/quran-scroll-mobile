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

    func testReaderResumeGlobalIDPersistsInAppGroup() {
        let store = AppGroupStore(suiteName: "test.resume.key.\(UUID().uuidString)")
        store.readerResumeGlobalID = 250
        XCTAssertEqual(store.readerResumeGlobalID, 250)
        XCTAssertEqual(ReaderResume.resumeGlobalID(store: store), 250)
    }

    func testBookmarkBehindKhatmIsTheOpenTarget() {
        let store = AppGroupStore(suiteName: "test.resume.bookmark.\(UUID().uuidString)")
        store.khatmCursor = 498
        store.readerResumeGlobalID = 498
        let bookmark = Bookmark(surahNumber: 2, ayahNumber: 255)

        XCTAssertEqual(
            ReaderResume.openTarget(bookmarks: [bookmark], store: store),
            .bookmark(surahNumber: 2, ayahNumber: 255)
        )
        XCTAssertTrue(store.readerResumePinnedByBookmark)
    }

    func testBookmarkBehindKhatmResolvesToBookmarkGlobalID() throws {
        guard let repository = try? BundledQuranRepository() else {
            throw XCTSkip("quran.sqlite not in test host bundle — run on Mac after xcodegen")
        }
        let store = AppGroupStore(suiteName: "test.resume.bookmark.id.\(UUID().uuidString)")
        store.khatmCursor = 498

        let target = try ReaderResume.openAyah(
            bookmarks: [Bookmark(surahNumber: 2, ayahNumber: 255)],
            store: store,
            repository: repository
        )

        XCTAssertEqual(target.id, 262)
        XCTAssertNotEqual(target.id, 498)
    }

    func testOpenTargetUsesResumeWhenThereIsNoBookmark() {
        let store = AppGroupStore(suiteName: "test.resume.position.\(UUID().uuidString)")
        store.khatmCursor = 498
        store.readerResumeGlobalID = 842

        XCTAssertEqual(
            ReaderResume.openTarget(bookmarks: [], store: store),
            .globalID(842)
        )
    }

    func testOpenTargetFallsBackToKhatmWhenBookmarkAndResumeAreUnset() {
        let store = AppGroupStore(suiteName: "test.resume.khatm.\(UUID().uuidString)")
        store.khatmCursor = 498

        XCTAssertEqual(
            ReaderResume.openTarget(bookmarks: [], store: store),
            .globalID(498)
        )
    }

    func testShieldAdvanceDoesNotMoveBookmarkPin() {
        let store = AppGroupStore(suiteName: "test.resume.pin.\(UUID().uuidString)")
        store.readerResumeGlobalID = 262
        store.khatmCursor = 498
        _ = ReaderResume.openTarget(
            bookmarks: [Bookmark(surahNumber: 2, ayahNumber: 255)],
            store: store
        )

        ReaderResume.syncResumeFromKhatmIfNeeded(store: store)

        XCTAssertEqual(store.readerResumeGlobalID, 262)
    }
}
