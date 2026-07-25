import Foundation

public protocol TranslationService: Sendable {
    func translation(for verseKey: String, translationId: Int) async throws -> String
    func prefetch(surah: Int, translationId: Int) async throws
}

public protocol TransliterationService: Sendable {
    func transliteration(for verseKey: String) async throws -> String
}

/// quran.com API v4 client with on-disk cache. Falls back to bundled Sahih Intl. offline.
public final class QuranComTranslationService: TranslationService, @unchecked Sendable {
    private let session: URLSession
    private let cacheDir: URL
    private let bundled: QuranRepository

    public init(bundled: QuranRepository, session: URLSession = .shared, cacheDir: URL? = nil) {
        self.bundled = bundled
        self.session = session
        if let cacheDir {
            self.cacheDir = cacheDir
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDir = base.appendingPathComponent("translations", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
    }

    public func translation(for verseKey: String, translationId: Int) async throws -> String {
        if translationId == 20 {
            return try bundled.ayah(verseKey: verseKey).translationEn
        }
        if let cached = loadCache(verseKey: verseKey, translationId: translationId) {
            return cached
        }
        let parts = verseKey.split(separator: ":")
        guard parts.count == 2, let chapter = Int(parts[0]), let ayah = Int(parts[1]) else {
            throw QuranRepositoryError.notFound
        }
        let url = URL(string: "https://api.quran.com/api/v4/verses/by_key/\(chapter):\(ayah)?translations=\(translationId)")!
        let (data, _) = try await session.data(from: url)
        let text = try Self.parseTranslation(data: data)
        saveCache(verseKey: verseKey, translationId: translationId, text: text)
        return text
    }

    public func prefetch(surah: Int, translationId: Int) async throws {
        let url = URL(string: "https://api.quran.com/api/v4/verses/by_chapter/\(surah)?translations=\(translationId)&per_page=300")!
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verses = json["verses"] as? [[String: Any]] else { return }
        for verse in verses {
            guard let key = verse["verse_key"] as? String,
                  let translations = verse["translations"] as? [[String: Any]],
                  let raw = translations.first?["text"] as? String else { continue }
            let cleaned = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            saveCache(verseKey: key, translationId: translationId, text: cleaned)
        }
    }

    private func cacheURL(verseKey: String, translationId: Int) -> URL {
        cacheDir.appendingPathComponent("\(translationId)_\(verseKey.replacingOccurrences(of: ":", with: "_")).txt")
    }

    private func loadCache(verseKey: String, translationId: Int) -> String? {
        try? String(contentsOf: cacheURL(verseKey: verseKey, translationId: translationId), encoding: .utf8)
    }

    private func saveCache(verseKey: String, translationId: Int, text: String) {
        try? text.write(to: cacheURL(verseKey: verseKey, translationId: translationId), atomically: true, encoding: .utf8)
    }

    private static func parseTranslation(data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verse = json["verse"] as? [String: Any],
              let translations = verse["translations"] as? [[String: Any]],
              let raw = translations.first?["text"] as? String else {
            throw QuranRepositoryError.notFound
        }
        return raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

public final class QuranComTransliterationService: TransliterationService, @unchecked Sendable {
    private let session: URLSession
    private let cacheDir: URL

    public init(session: URLSession = .shared) {
        self.session = session
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = base.appendingPathComponent("transliteration", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public func transliteration(for verseKey: String) async throws -> String {
        let file = cacheDir.appendingPathComponent(verseKey.replacingOccurrences(of: ":", with: "_") + ".txt")
        if let cached = try? String(contentsOf: file, encoding: .utf8) { return cached }
        // resource_id 57 is a common transliteration on quran.com; adjust if needed.
        let url = URL(string: "https://api.quran.com/api/v4/quran/translations/57?verse_key=\(verseKey)")!
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let text = translations.first?["text"] as? String else {
            throw QuranRepositoryError.notFound
        }
        let cleaned = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        try? cleaned.write(to: file, atomically: true, encoding: .utf8)
        return cleaned
    }
}
