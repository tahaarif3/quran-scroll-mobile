import Foundation

public struct SurahMeta: Equatable, Identifiable, Sendable {
    public var id: Int { number }
    public let number: Int
    public let nameArabic: String
    public let nameEnglish: String
    public let nameTransliteration: String
    public let ayahCount: Int
    public let revelationPlace: String

    public init(
        number: Int,
        nameArabic: String,
        nameEnglish: String,
        nameTransliteration: String,
        ayahCount: Int,
        revelationPlace: String
    ) {
        self.number = number
        self.nameArabic = nameArabic
        self.nameEnglish = nameEnglish
        self.nameTransliteration = nameTransliteration
        self.ayahCount = ayahCount
        self.revelationPlace = revelationPlace
    }

    public var subtitle: String {
        "\(number) · \(nameTransliteration)"
    }
}

public struct Ayah: Equatable, Identifiable, Sendable {
    public var id: Int
    public let surah: Int
    public let ayah: Int
    public let verseKey: String
    public let textUthmani: String
    public let translationEn: String
    public let page: Int
    public var transliteration: String?

    public init(
        id: Int,
        surah: Int,
        ayah: Int,
        verseKey: String,
        textUthmani: String,
        translationEn: String,
        page: Int,
        transliteration: String? = nil
    ) {
        self.id = id
        self.surah = surah
        self.ayah = ayah
        self.verseKey = verseKey
        self.textUthmani = textUthmani
        self.translationEn = translationEn
        self.page = page
        self.transliteration = transliteration
    }
}

public struct QuranPage: Equatable, Sendable {
    public let pageNumber: Int
    public let ayahs: [Ayah]

    public init(pageNumber: Int, ayahs: [Ayah]) {
        self.pageNumber = pageNumber
        self.ayahs = ayahs
    }
}

/// Curated ayah-of-the-day list — deterministic by day-of-year.
public enum AyahOfTheDay {
    public static let curatedKeys: [String] = [
        "2:286", "94:5", "94:6", "13:28", "2:152", "3:191", "39:53",
        "65:3", "2:153", "14:7", "18:10", "21:87", "25:74", "33:41",
        "48:4", "55:13", "57:4", "67:2", "93:5", "112:1"
    ]

    public static func key(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return curatedKeys[(day - 1) % curatedKeys.count]
    }
}
