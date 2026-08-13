import Foundation
import UIKit

/// Supplies the ayah shown on the OS shield.
///
/// `ShieldConfiguration` gives no control over fonts and truncates rather than shrinking, so the
/// pool is restricted to genuinely short ayahs and the Arabic is drawn into the icon image —
/// the one part of the shield we render ourselves — instead of being handed to a system label.
public enum ShieldAyahProvider {
    /// Short, well-known ayahs. Length is the selection criterion, not just meaning: anything
    /// long is truncated mid-sentence by the system, which reads worse than not showing it.
    public static let verseKeys = [
        "94:5", "94:6", "2:152", "13:28", "65:3", "2:286",
        "3:191", "39:53", "14:7", "21:87", "33:41", "55:13",
        "57:4", "67:2", "93:5", "112:1", "18:10", "25:74"
    ]

    /// Rotates with how much has been read today, so every tap of "I've read this ayah" brings a
    /// different one rather than re-showing the same verse.
    public static func verseKey(for store: AppGroupStore = .shared) -> String {
        let offset = store.pagesReadToday * store.ayahsPerPage + store.ayahsReadToday
        return verseKeys[abs(offset) % verseKeys.count]
    }

    public static func ayah(for store: AppGroupStore = .shared) -> Ayah? {
        guard let repository = try? BundledQuranRepository() else { return nil }
        return try? repository.ayah(verseKey: verseKey(for: store))
    }

    /// Progress line for the shield subtitle, in ayahs rather than pages so that a single ayah
    /// visibly moves it. A page-only counter would sit unchanged for nine taps out of ten.
    public static func progressLine(for store: AppGroupStore = .shared) -> String {
        let pages = store.pagesReadToday
        let goal = store.dailyGoalPages
        let into = store.ayahsReadToday
        let per = store.ayahsPerPage
        if pages >= goal { return "Today's goal is complete." }
        return "\(pages)/\(goal) pages · \(into)/\(per) ayahs to the next"
    }

    // MARK: - Arabic rendering

    /// Draws the Arabic into an image, shrinking the font until it fits.
    ///
    /// This exists because the shield's labels expose no font control. Rendering it ourselves is
    /// the only way to keep Amiri, control the size, and wrap rather than truncate. UIKit's text
    /// drawing goes through CoreText, so Arabic shaping and right-to-left ordering are correct.
    public static func arabicImage(
        for ayah: Ayah,
        size: CGSize = CGSize(width: 320, height: 200),
        color: UIColor = UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 1)
    ) -> UIImage? {
        IQFontRegistrar.registerIfNeeded()

        let inset = CGRect(origin: .zero, size: size).insetBy(dx: 12, dy: 12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineBreakMode = .byWordWrapping

        // Descend until it fits rather than truncating. 15pt is the floor — below that it is not
        // readable on a shield and showing nothing is more honest than showing a smear.
        var attributes: [NSAttributedString.Key: Any] = [:]
        var fitted = false
        for pointSize in stride(from: 34.0, through: 15.0, by: -1.0) {
            let font = UIFont(name: "Amiri-Bold", size: pointSize)
                ?? .systemFont(ofSize: pointSize, weight: .semibold)
            paragraph.lineSpacing = pointSize * 0.35
            attributes = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            let bounds = (ayah.textUthmani as NSString).boundingRect(
                with: CGSize(width: inset.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            if bounds.height <= inset.height {
                fitted = true
                break
            }
        }
        guard fitted else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let text = ayah.textUthmani as NSString
            let bounds = text.boundingRect(
                with: CGSize(width: inset.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let origin = CGPoint(
                x: inset.minX,
                y: inset.minY + max(0, (inset.height - bounds.height) / 2)
            )
            text.draw(
                with: CGRect(origin: origin, size: CGSize(width: inset.width, height: bounds.height)),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }
    }
}
