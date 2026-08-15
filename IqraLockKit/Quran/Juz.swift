import Foundation

/// The thirty juz of the mushaf, as first-ayah boundaries.
///
/// A static table rather than a database column: these divisions are fixed and universally
/// agreed, so reshaping the schema to store what is effectively a constant would only add a
/// migration for no benefit. Values are the sequential ayah id (1...6236) each juz begins at.
public enum Juz {
    public static let count = 30

    /// First ayah of each juz, in order.
    public static let firstAyahIDs: [Int] = [
        1,    149,  260,  386,  517,  641,  751,  900,  1042, 1201,
        1328, 1479, 1649, 1803, 1902, 2030, 2215, 2484, 2674, 2876,
        3215, 3386, 3564, 3733, 3971, 4090, 4265, 4511, 4706, 5673
    ]

    /// Which juz an ayah falls in, 1...30.
    public static func number(forAyahID id: Int) -> Int {
        let clamped = min(max(1, id), AppGroupStore.ayahsInMushaf)
        // Last boundary at or below the id.
        var result = 1
        for (index, start) in firstAyahIDs.enumerated() where start <= clamped {
            result = index + 1
        }
        return result
    }

    /// Ayahs remaining until the next juz begins, or until the end of the mushaf in the thirtieth.
    public static func ayahsToNextBoundary(fromAyahID id: Int) -> Int {
        let clamped = min(max(1, id), AppGroupStore.ayahsInMushaf)
        for start in firstAyahIDs where start > clamped {
            return start - clamped
        }
        return AppGroupStore.ayahsInMushaf - clamped + 1
    }

    /// How far through the current juz, 0...1.
    public static func progress(atAyahID id: Int) -> Double {
        let clamped = min(max(1, id), AppGroupStore.ayahsInMushaf)
        let current = number(forAyahID: clamped)
        let start = firstAyahIDs[current - 1]
        let end = current < count ? firstAyahIDs[current] : AppGroupStore.ayahsInMushaf + 1
        let span = max(1, end - start)
        return min(1, max(0, Double(clamped - start) / Double(span)))
    }
}
