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
    public static func ayah(for store: AppGroupStore = .shared) -> Ayah? {
        guard let repository = try? BundledQuranRepository() else { return nil }
        return try? repository.ayah(globalID: store.khatmCursor)
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

        // Descend until it fits. Now that ayahs are served sequentially rather than picked for
        // brevity, long ones do occur — 12pt is the floor and the smallest size is used even if
        // it still overflows, because dropping the Arabic entirely is worse than a tight fit.
        var attributes: [NSAttributedString.Key: Any] = [:]
        var fitted = false
        for pointSize in stride(from: 34.0, through: 12.0, by: -1.0) {
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
        // `attributes` holds the floor size when nothing fitted; render at that rather than
        // bailing out. The very longest ayahs will be cramped, which is a fair price for the
        // cursor covering the whole mushaf in order.
        _ = fitted

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
