import Foundation
import UIKit

/// Supplies the ayah shown on the OS shield.
///
/// `ShieldConfiguration` gives no control over fonts and truncates rather than shrinking, so the
/// pool is restricted to genuinely short ayahs and the Arabic is drawn into the icon image —
/// the one part of the shield we render ourselves — instead of being handed to a system label.
public enum ShieldAyahProvider {
    /// The next ayah in the mushaf, taken from the shared khatm cursor.
    ///
    /// Sequential rather than a curated list, so that reading from the shield genuinely moves
    /// the reader through the Qur'an. A rotating pool of short verses made the khatm counter
    /// false — the same eighteen ayahs, every tenth tap claiming another page read.
    ///
    /// The cost is that some ayahs are long, and the shield truncates its subtitle. That is a
    /// smaller price than a progress number that isn't true.
    /// How many ayahs ahead the app caches, so the shield can advance repeatedly on its own.
    ///
    /// Generous on purpose. Once the window is exhausted the shield has nothing to show until
    /// the app is next opened — and the whole point of reading from the shield is that the user
    /// never has to open the app. At roughly 300 bytes an ayah this is well under any practical
    /// limit for an App Group defaults entry.
    public static let cacheWindow = 150

    /// Cache first, database second.
    ///
    /// Opening the bundled SQLite from inside the shield extension returned nothing on device —
    /// the shield rendered its bare fallback with no ayah at all. Extensions get a hard memory
    /// and time budget, so the app now writes plain strings ahead of time and this only reads
    /// them. The direct lookup stays as a fallback for the first run, before the app has filled
    /// the window.
    public static func ayah(for store: AppGroupStore = .shared) -> Ayah? {
        if let cached = store.cachedAyahAtCursor {
            return Ayah(
                id: cached.id,
                surah: 0,
                ayah: 0,
                verseKey: cached.verseKey,
                textUthmani: cached.arabic,
                translationEn: cached.translation,
                page: 0
            )
        }
        guard let repository = try? BundledQuranRepository() else { return nil }
        return try? repository.ayah(globalID: store.khatmCursor)
    }

    /// Fills the window from the cursor forward. Called by the app, never the extension.
    public static func refreshCache(store: AppGroupStore = .shared) {
        guard let repository = try? BundledQuranRepository() else { return }
        let start = store.khatmCursor
        var window: [AppGroupStore.CachedAyah] = []
        window.reserveCapacity(cacheWindow)
        for offset in 0..<cacheWindow {
            var id = start + offset
            if id > AppGroupStore.ayahsInMushaf { id -= AppGroupStore.ayahsInMushaf }
            guard let ayah = try? repository.ayah(globalID: id) else { continue }
            window.append(
                AppGroupStore.CachedAyah(
                    id: ayah.id,
                    verseKey: ayah.verseKey,
                    arabic: ayah.textUthmani,
                    translation: ayah.translationEn
                )
            )
        }
        store.cachedAyahs = window
    }

    public struct Segmented {
        public let arabic: String
        public let translation: String
        /// Carries "· 2 of 3" when the ayah is broken up, so the reader knows a pause is coming.
        public let reference: String
        public let index: Int
        public let count: Int

        public var isFinalSegment: Bool { index >= count - 1 }
        /// Naming the next action honestly: there is more of *this* ayah, not a new one.
        public var secondaryLabel: String { isFinalSegment ? "Read another ayah" : "Read the rest" }
    }

    /// The ayah at the cursor, divided at waqf marks if it cannot be legible whole.
    ///
    /// Only the final segment counts toward the goal and moves the cursor; each segment earns
    /// its own window, because each is a real act of reading.
    public static func segmented(for store: AppGroupStore = .shared) -> Segmented? {
        guard let ayah = ayah(for: store) else { return nil }
        let pieces = ShieldAyahSegmenter.segments(of: ayah.textUthmani) {
            ShieldIconComposer.fitsWhole($0)
        }
        let index = min(store.shieldSegmentIndex, pieces.count - 1)
        let reference = pieces.count > 1
            ? "\(ayah.verseKey) · \(index + 1) of \(pieces.count)"
            : ayah.verseKey
        return Segmented(
            arabic: pieces[index],
            // The translation belongs to the whole ayah; showing a fragment of it against a
            // fragment of the Arabic would imply a correspondence that isn't there.
            translation: ayah.translationEn,
            reference: reference,
            index: index,
            count: pieces.count
        )
    }

    /// How many pieces the ayah at the cursor divides into. Used by the action extension to know
    /// whether a read finishes the ayah.
    public static func segmentCount(for store: AppGroupStore = .shared) -> Int {
        guard let ayah = ayah(for: store) else { return 1 }
        return ShieldAyahSegmenter.segments(of: ayah.textUthmani) {
            ShieldIconComposer.fitsWhole($0)
        }.count
    }

    /// The subtitle's single job: progress. It is the only one of its three former contents that
    /// changes between renders and so cannot be baked into the cached image. Held under 55
    /// characters at every value so it can never truncate.
    public static func progressLine(for store: AppGroupStore = .shared) -> String {
        if store.goalMetToday { return "Today's goal is done — open until tomorrow" }
        let remaining = max(0, store.dailyGoalAyahs - store.totalAyahsToday)
        if remaining == 1 { return "One more ayah opens everything until tomorrow" }
        // At page scale the ayah count stops being meaningful to a reader.
        if remaining >= store.ayahsPerPage * 2 {
            let pages = Int((Double(remaining) / Double(max(1, store.ayahsPerPage))).rounded())
            return "About \(pages) pages to today's goal"
        }
        return "\(remaining) ayahs to today's goal, then open until tomorrow"
    }

    /// The title's single job: the exchange rate, not the state. "Instagram is locked" spends the
    /// loudest slot telling the user what they already learned by arriving. Tracks the user's own
    /// 5–120 minute setting and stays under 44 characters at every value.
    public static func titleLine(appName: String, store: AppGroupStore = .shared) -> String {
        "One ayah opens \(appName) for \(store.ayahUnlockMinutes) minutes"
    }

    /// Names the destination and the price. Burying the action the user came for is what makes a
    /// shield feel like a paywall.
    public static func primaryLabel(appName: String, store: AppGroupStore = .shared) -> String {
        "Open \(appName) · \(store.ayahUnlockMinutes) min"
    }
}
