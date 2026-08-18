import Foundation
import UIKit

/// Supplies the ayah shown on the OS shield.
///
/// The Arabic goes in the title slot and the translation in the subtitle. Drawing the Arabic into
/// the icon instead — the one part of the shield we render ourselves — gave us full control of its
/// typography and turned out to be the wrong trade: iOS renders that icon small whatever we put in
/// it, so the Arabic came out smaller than the English no matter how the square was divided. The
/// text slots are sized by iOS to be read, which is the property that actually mattered.
///
/// `ShieldConfiguration` truncates rather than shrinking, so an ayah too long for the slot is
/// divided at a waqf mark instead.
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

        /// The meaning, then where it comes from. The subtitle carries both because the title
        /// slot now belongs to the Arabic.
        public var subtitle: String { "\(translation)\n\(reference)" }
    }

    /// The ayah at the cursor, divided at waqf marks if it cannot be legible whole.
    ///
    /// Only the final segment counts toward the goal and moves the cursor; each segment earns
    /// its own window, because each is a real act of reading.
    public static func segmented(for store: AppGroupStore = .shared) -> Segmented? {
        guard let ayah = ayah(for: store) else { return nil }
        let pieces = ShieldAyahSegmenter.segments(of: ayah.textUthmani, fitting: fitsTitleSlot)
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
        return ShieldAyahSegmenter.segments(of: ayah.textUthmani, fitting: fitsTitleSlot).count
    }

    /// Whether this much Arabic fits the shield's title slot without being truncated.
    ///
    /// iOS owns that slot's typography and offers no way to measure it, so this is a budget
    /// rather than a fit: count the letters the eye actually sees and cap them. Combining marks
    /// are excluded because Uthmani text carries a great many of them and none take horizontal
    /// space — counting them would segment ayahs that fit perfectly well.
    static func fitsTitleSlot(_ arabic: String) -> Bool {
        arabic.unicodeScalars.reduce(0) { count, scalar in
            isCombiningMark(scalar) ? count : count + 1
        } <= maxTitleCharacters
    }

    /// Roughly three lines of the title slot on a current iPhone. Deliberately conservative: an
    /// ayah divided once too often still reads correctly, one that truncates does not.
    static let maxTitleCharacters = 95

    private static func isCombiningMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x064B...0x065F, 0x0670, 0x06D6...0x06ED: return true
        default: return false
        }
    }

    /// Names the destination and the price. Burying the action the user came for is what makes a
    /// shield feel like a paywall.
    public static func primaryLabel(appName: String, store: AppGroupStore = .shared) -> String {
        "Open \(appName) · \(store.ayahUnlockMinutes) min"
    }
}
