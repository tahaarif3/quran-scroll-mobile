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
        XCTAssertEqual(store.readerResumeGlobalID, 262)
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

    func testShieldUsesReaderCursorInsteadOfKhatmCursor() {
        let store = AppGroupStore(suiteName: "test.shield.reader.cursor.\(UUID().uuidString)")
        store.khatmCursor = 498
        store.readerResumeGlobalID = 262
        store.cachedAyahs = [
            AppGroupStore.CachedAyah(
                id: 262,
                verseKey: "2:255",
                arabic: "آية الكرسي",
                translation: "Ayat al-Kursi"
            ),
            AppGroupStore.CachedAyah(
                id: 498,
                verseKey: "4:5",
                arabic: "النساء",
                translation: "An-Nisa"
            )
        ]

        let shieldAyah = ShieldAyahProvider.ayah(for: store)

        XCTAssertEqual(ReaderResume.shieldGlobalID(store: store), 262)
        XCTAssertEqual(shieldAyah?.id, 262)
        XCTAssertEqual(shieldAyah?.verseKey, "2:255")
    }

    func testShieldReadAdvancesFromDisplayedReaderCursor() {
        let store = AppGroupStore(suiteName: "test.shield.reader.advance.\(UUID().uuidString)")
        store.khatmCursor = 498
        store.readerResumeGlobalID = 262

        ReaderResume.advanceAfterShieldRead(globalID: 262, store: store)

        XCTAssertEqual(store.readerResumeGlobalID, 263)
        XCTAssertEqual(store.khatmCursor, 498)
    }
}
