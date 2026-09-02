import Foundation
import SwiftData

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

    /// If the shield advanced the khatm cursor while the app was closed, pull resume forward.
    public static func syncResumeFromKhatmIfNeeded(store: AppGroupStore) {
        let resume = resumeGlobalID(store: store)
        if store.khatmCursor > resume {
            store.readerResumeGlobalID = store.khatmCursor
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
