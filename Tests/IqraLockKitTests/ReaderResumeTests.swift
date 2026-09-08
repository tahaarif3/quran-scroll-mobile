import XCTest
import SwiftData
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

    func testReaderOpensFromResumeRatherThanBookmark() throws {
        guard let repository = try? BundledQuranRepository() else {
            throw XCTSkip("quran.sqlite not in test host bundle — run on Mac after xcodegen")
        }
        let store = AppGroupStore(suiteName: "test.resume.open.\(UUID().uuidString)")
        store.khatmCursor = 498
        store.readerResumeGlobalID = 262

        let target = try ReaderResume.openAyah(
            store: store,
            repository: repository
        )

        XCTAssertEqual(target.id, 262)
        XCTAssertNotEqual(target.id, 498)
    }

    func testShieldUsesKhatmCursorInsteadOfReaderOrBookmark() {
        let store = AppGroupStore(suiteName: "test.shield.khatm.cursor.\(UUID().uuidString)")
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

        XCTAssertEqual(shieldAyah?.id, 498)
        XCTAssertEqual(shieldAyah?.verseKey, "4:5")
    }

    func testBookmarkListPersistsWithoutMovingResumeOrKhatm() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Bookmark.self, configurations: configuration)
        let context = ModelContext(container)
        let store = AppGroupStore(suiteName: "test.bookmark.list.\(UUID().uuidString)")
        store.khatmCursor = 498
        store.readerResumeGlobalID = 600
        let first = sampleAyah(id: 262, surah: 2, ayah: 255)
        let second = sampleAyah(id: 293, surah: 2, ayah: 286)

        XCTAssertTrue(try ReaderResume.toggleBookmark(ayah: first, context: context))
        XCTAssertTrue(try ReaderResume.toggleBookmark(
            ayah: second,
            context: context
        ))

        let verificationContext = ModelContext(container)
        let saved = try verificationContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(Set(saved.map(\.note)), Set(["2:255", "2:286"]))
        XCTAssertEqual(store.readerResumeGlobalID, 600)
        XCTAssertEqual(store.khatmCursor, 498)

        XCTAssertFalse(try ReaderResume.toggleBookmark(ayah: first, context: context))
        let afterRemoval = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(afterRemoval.count, 1)
        XCTAssertEqual(afterRemoval.first?.note, "2:286")
    }

    private func sampleAyah(id: Int, surah: Int, ayah: Int) -> Ayah {
        Ayah(
            id: id,
            surah: surah,
            ayah: ayah,
            verseKey: "\(surah):\(ayah)",
            textUthmani: "test",
            translationEn: "test",
            page: 1
        )
    }
}
