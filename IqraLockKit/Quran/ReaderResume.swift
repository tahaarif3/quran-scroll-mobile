import Foundation
import SwiftData

public enum ReaderOpenTarget: Equatable {
    case bookmark(surahNumber: Int, ayahNumber: Int)
    case globalID(Int)
}

/// Where the reader and Home tab resume — separate from `khatmCursor`, which only moves forward.
public enum ReaderResume {
    /// Last place the user was reading in the app (may be ahead of or behind khatm progress).
    public static func resumeGlobalID(store: AppGroupStore) -> Int {
        let stored = store.readerResumeGlobalID
        if stored > 0 { return stored }
        return store.khatmCursor
    }

    public static func save(globalID: Int, store: AppGroupStore) {
        guard (1...AppGroupStore.ayahsInMushaf).contains(globalID) else { return }
        store.readerResumeGlobalID = globalID
    }

    public static func save(ayah: Ayah, store: AppGroupStore) {
        save(globalID: ayah.id, store: store)
    }

    /// The shield follows the user's in-app reading cursor, not the independent khatm cursor.
    public static func shieldGlobalID(store: AppGroupStore) -> Int {
        let stored = store.readerResumeGlobalID
        return stored > 0 ? stored : store.khatmCursor
    }

    /// Move both progress streams after the shield finishes the ayah it actually displayed.
    public static func advanceAfterShieldRead(globalID: Int, store: AppGroupStore) {
        guard (1...AppGroupStore.ayahsInMushaf).contains(globalID) else { return }
        let nextID = globalID == AppGroupStore.ayahsInMushaf ? 1 : globalID + 1
        store.advanceKhatmCursor(toAyahID: globalID + 1)
        store.readerResumeGlobalID = nextID
    }

    /// One policy for every reader entry point: an explicit bookmark is a pin; otherwise use
    /// the last in-app position, then finally the khatm cursor.
    public static func openTarget(
        bookmarks: [Bookmark],
        store: AppGroupStore
    ) -> ReaderOpenTarget {
        if let bookmark = bookmarks
            .filter({ $0.surahNumber > 0 && $0.ayahNumber > 0 })
            .max(by: { $0.createdAt < $1.createdAt }) {
            return .bookmark(
                surahNumber: bookmark.surahNumber,
                ayahNumber: bookmark.ayahNumber
            )
        }

        let stored = store.readerResumeGlobalID
        return .globalID(stored > 0 ? stored : store.khatmCursor)
    }

    public static func openAyah(
        bookmarks: [Bookmark],
        store: AppGroupStore,
        repository: QuranRepository
    ) throws -> Ayah {
        switch openTarget(bookmarks: bookmarks, store: store) {
        case let .bookmark(surahNumber, ayahNumber):
            let ayah = try repository.ayah(surah: surahNumber, ayah: ayahNumber)
            save(ayah: ayah, store: store)
            return ayah
        case let .globalID(globalID):
            return try repository.ayah(globalID: globalID)
        }
    }

    public static func upsertReadingPosition(
        ayah: Ayah,
        positions: [ReadingPosition],
        context: ModelContext
    ) {
        let pos = positions.first ?? {
            let created = ReadingPosition(
                surahNumber: ayah.surah,
                ayahNumber: ayah.ayah,
                pageNumber: ayah.page
            )
            context.insert(created)
            return created
        }()
        pos.surahNumber = ayah.surah
        pos.ayahNumber = ayah.ayah
        pos.pageNumber = ayah.page
        pos.updatedAt = Date()
        try? context.save()
    }

    public static func setBookmark(
        ayah: Ayah,
        bookmarks: [Bookmark],
        positions: [ReadingPosition],
        context: ModelContext,
        store: AppGroupStore
    ) {
        save(ayah: ayah, store: store)
        upsertReadingPosition(ayah: ayah, positions: positions, context: context)

        if let existing = bookmarks.first {
            existing.surahNumber = ayah.surah
            existing.ayahNumber = ayah.ayah
            existing.createdAt = Date()
            existing.note = ayah.verseKey
        } else {
            context.insert(Bookmark(
                surahNumber: ayah.surah,
                ayahNumber: ayah.ayah,
                note: ayah.verseKey
            ))
        }
        try? context.save()
    }
}
