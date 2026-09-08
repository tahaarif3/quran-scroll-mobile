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

    public static func openAyah(
        store: AppGroupStore,
        repository: QuranRepository
    ) throws -> Ayah {
        try repository.ayah(globalID: resumeGlobalID(store: store))
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

    /// Bookmarks are a persistent list, independent from resume and khatm progress.
    /// Returns true when the ayah was saved and false when an existing bookmark was removed.
    @discardableResult
    public static func toggleBookmark(
        ayah: Ayah,
        context: ModelContext
    ) throws -> Bool {
        let saved = try context.fetch(FetchDescriptor<Bookmark>())
        if let existing = saved.first(where: {
            $0.surahNumber == ayah.surah && $0.ayahNumber == ayah.ayah
        }) {
            context.delete(existing)
            try context.save()
            return false
        } else {
            context.insert(Bookmark(
                surahNumber: ayah.surah,
                ayahNumber: ayah.ayah,
                note: ayah.verseKey
            ))
            try context.save()
            return true
        }
    }
}
