import Foundation
import SQLite3

public protocol QuranRepository: Sendable {
    func surah(number: Int) throws -> SurahMeta
    func allSurahs() throws -> [SurahMeta]
    func ayahs(forSurah number: Int) throws -> [Ayah]
    func ayah(surah: Int, ayah: Int) throws -> Ayah
    func ayah(verseKey: String) throws -> Ayah
    func page(_ pageNumber: Int) throws -> QuranPage
    func pageNumber(surah: Int, ayah: Int) throws -> Int
    func arabicChecksum() throws -> String
}

public enum QuranRepositoryError: Error, Equatable {
    case databaseMissing
    case openFailed
    case notFound
    case queryFailed
}

/// Read-only access to bundled `quran.sqlite`.
/// IMPORTANT: `text_uthmani` must remain byte-identical to the source (CC BY / Tanzil).
/// Do not NFC/NFD-normalize or strip diacritics from the display column.
public final class BundledQuranRepository: QuranRepository, @unchecked Sendable {
    private var db: OpaquePointer?
    private let path: String

    public init(bundle: Bundle = .main) throws {
        // Framework bundle first, then main.
        let candidates: [URL?] = [
            Bundle(for: BundledQuranRepository.self).url(forResource: "quran", withExtension: "sqlite"),
            bundle.url(forResource: "quran", withExtension: "sqlite"),
            Bundle.main.url(forResource: "quran", withExtension: "sqlite")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw QuranRepositoryError.databaseMissing
        }
        self.path = url.path
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw QuranRepositoryError.openFailed
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func arabicChecksum() throws -> String {
        try stringMeta("arabic_sha256")
    }

    public func allSurahs() throws -> [SurahMeta] {
        let sql = "SELECT number, name_arabic, name_english, name_transliteration, ayah_count, revelation_place FROM surahs ORDER BY number;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw QuranRepositoryError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        var result: [SurahMeta] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(readSurah(stmt))
        }
        return result
    }

    public func surah(number: Int) throws -> SurahMeta {
        let sql = "SELECT number, name_arabic, name_english, name_transliteration, ayah_count, revelation_place FROM surahs WHERE number = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw QuranRepositoryError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(number))
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw QuranRepositoryError.notFound }
        return readSurah(stmt)
    }

    public func ayahs(forSurah number: Int) throws -> [Ayah] {
        let sql = "SELECT id, surah, ayah, verse_key, text_uthmani, translation_en, page FROM ayahs WHERE surah = ? ORDER BY ayah;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw QuranRepositoryError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(number))
        var rows: [Ayah] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(readAyah(stmt))
        }
        return rows
    }

    public func ayah(surah: Int, ayah: Int) throws -> Ayah {
        let sql = "SELECT id, surah, ayah, verse_key, text_uthmani, translation_en, page FROM ayahs WHERE surah = ? AND ayah = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw QuranRepositoryError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(surah))
        sqlite3_bind_int(stmt, 2, Int32(ayah))
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw QuranRepositoryError.notFound }
        return readAyah(stmt)
    }

    public func ayah(verseKey: String) throws -> Ayah {
        let parts = verseKey.split(separator: ":")
        guard parts.count == 2, let s = Int(parts[0]), let a = Int(parts[1]) else {
            throw QuranRepositoryError.notFound
        }
        return try ayah(surah: s, ayah: a)
    }

    public func page(_ pageNumber: Int) throws -> QuranPage {
        let sql = "SELECT id, surah, ayah, verse_key, text_uthmani, translation_en, page FROM ayahs WHERE page = ? ORDER BY id;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw QuranRepositoryError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(pageNumber))
        var rows: [Ayah] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(readAyah(stmt))
        }
        guard !rows.isEmpty else { throw QuranRepositoryError.notFound }
        return QuranPage(pageNumber: pageNumber, ayahs: rows)
    }

    public func pageNumber(surah: Int, ayah: Int) throws -> Int {
        try self.ayah(surah: surah, ayah: ayah).page
    }

    private func stringMeta(_ key: String) throws -> String {
        let sql = "SELECT value FROM meta WHERE key = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw QuranRepositoryError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let c = sqlite3_column_text(stmt, 0) else {
            throw QuranRepositoryError.notFound
        }
        return String(cString: c)
    }

    private func readSurah(_ stmt: OpaquePointer?) -> SurahMeta {
        SurahMeta(
            number: Int(sqlite3_column_int(stmt, 0)),
            nameArabic: String(cString: sqlite3_column_text(stmt, 1)),
            nameEnglish: String(cString: sqlite3_column_text(stmt, 2)),
            nameTransliteration: String(cString: sqlite3_column_text(stmt, 3)),
            ayahCount: Int(sqlite3_column_int(stmt, 4)),
            revelationPlace: String(cString: sqlite3_column_text(stmt, 5))
        )
    }

    private func readAyah(_ stmt: OpaquePointer?) -> Ayah {
        Ayah(
            id: Int(sqlite3_column_int(stmt, 0)),
            surah: Int(sqlite3_column_int(stmt, 1)),
            ayah: Int(sqlite3_column_int(stmt, 2)),
            verseKey: String(cString: sqlite3_column_text(stmt, 3)),
            textUthmani: String(cString: sqlite3_column_text(stmt, 4)),
            translationEn: String(cString: sqlite3_column_text(stmt, 5)),
            page: Int(sqlite3_column_int(stmt, 6))
        )
    }
}
