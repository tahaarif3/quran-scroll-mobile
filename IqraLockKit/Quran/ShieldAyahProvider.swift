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

    /// Progress line for the shield subtitle, in ayahs rather than pages so that a single ayah
    /// visibly moves it. A page-only counter would sit unchanged for nine taps out of ten, and
    /// now that the goal can be smaller than a page it could not describe it at all.
    public static func progressLine(for store: AppGroupStore = .shared) -> String {
        if store.goalMetToday { return "Today's goal is complete." }
        let read = store.totalAyahsToday
        let goal = store.dailyGoalAyahs
        return "\(read) of \(goal) ayahs today · goal \(store.goalDescription)"
    }

    // MARK: - Arabic rendering

    /// Draws the Arabic into an image, shrinking the font until it fits.
    ///
    /// This exists because the shield's labels expose no font control. Rendering it ourselves is
    /// the only way to keep Amiri, control the size, and wrap rather than truncate. UIKit's text
    /// drawing goes through CoreText, so Arabic shaping and right-to-left ordering are correct.
    public static func arabicImage(
        for ayah: Ayah,
        width: CGFloat = 300,
        maxHeight: CGFloat = 340,
        color: UIColor = UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 1)
    ) -> UIImage? {
        // Only the face actually used. Registering all eight in an extension that relaunches on
        // every presentation is what made "Read another ayah" feel slow.
        IQFontRegistrar.register("Amiri-Bold")

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineBreakMode = .byWordWrapping

        let text = ayah.textUthmani as NSString
        let available = CGSize(width: width, height: .greatestFiniteMagnitude)

        func attributes(at pointSize: CGFloat) -> [NSAttributedString.Key: Any] {
            let style = paragraph.mutableCopy() as! NSMutableParagraphStyle
            style.lineSpacing = pointSize * 0.34
            return [
                .font: UIFont(name: "Amiri-Bold", size: pointSize)
                    ?? .systemFont(ofSize: pointSize, weight: .semibold),
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        }

        // Start far higher than before. iOS scales this image down into its icon slot, so what
        // matters is how much of the image the text occupies, not the absolute point size —
        // rendering 34pt text on a fixed 320x200 canvas left it tiny on screen.
        var chosen = attributes(at: 30)
        var bounds = CGSize(width: width, height: 0)
        for pointSize in stride(from: 96.0, through: 30.0, by: -2.0) {
            let candidate = attributes(at: pointSize)
            let rect = text.boundingRect(
                with: available,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: candidate,
                context: nil
            )
            if rect.height <= maxHeight {
                chosen = candidate
                bounds = CGSize(width: width, height: ceil(rect.height))
                break
            }
        }
        if bounds.height == 0 {
            // Longest ayahs: keep the floor size and accept the full height rather than drop the
            // Arabic. Cramped is better than absent.
            let rect = text.boundingRect(
                with: available,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: chosen,
                context: nil
            )
            bounds = CGSize(width: width, height: ceil(rect.height))
        }

        // Canvas sized to the text, so no space is wasted and the glyphs survive the downscale
        // as large as they can be.
        let canvas = CGSize(width: width, height: bounds.height + 16)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            text.draw(
                with: CGRect(x: 0, y: 8, width: width, height: bounds.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: chosen,
                context: nil
            )
        }
    }
}
