import CoreText
import Foundation
import UIKit

/// Draws the shield's icon — the one slot whose typography we control.
///
/// It holds the Arabic and nothing else. Apparent size is the fraction of the frame the text
/// occupies, because iOS scales the whole square into a box of its own choosing: every point
/// spent on a reference line, a hairline or a translation comes directly out of the Arabic.
/// Sharing the square three ways left each line at roughly 28% of frame and unreadable on
/// device. Alone, the Arabic gets more than three times the area, and the reference and
/// translation move to the text slots where iOS sizes them legibly for free.
public enum ShieldIconComposer {
    /// Square, always. iOS aspect-fits into a square box, so any other ratio throws away scale —
    /// the same pixels as a 3:1 banner render a third the height. 160pt is what current iPhones
    /// give; every dimension below is a percentage because that is not contractual.
    public static let boxPoints: CGFloat = 160
    public static let renderScale: CGFloat = 3

    private enum Zone {
        static let bleedGuard: CGFloat = 0.02
        static let top: CGFloat = 0.04
        static let bottom: CGFloat = 0.96
        static var height: CGFloat { bottom - top }
    }

    /// The size an ayah has to reach to be worth showing whole — 14% of the frame, against the
    /// 7.5% floor of the three-way split. Anything that can't reach it is divided at a waqf mark
    /// instead of shrunk, so this is a segmentation threshold and not a rendering limit: it sets
    /// the *worst* case at roughly double the old one, and a segmented piece renders larger
    /// still.
    private static let comfortableFraction: CGFloat = 0.14

    /// The point below which we stop shrinking. Only reached by an ayah long enough to need
    /// splitting but printed without a single waqf mark to split on — rare, and small is still
    /// better than the clipped text that a hard stop here would produce.
    private static let hardMinimumFraction: CGFloat = 0.045

    /// Four lines is the most that stays legible once the square is scaled into the shield's box.
    private static let maxLines = 4

    private static let cream = UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 1)

    public struct Composition {
        public let image: UIImage
        /// The icon is an image, so its content is invisible to VoiceOver. This carries it.
        public let accessibilityLabel: String
    }

    /// Whether this Arabic sets comfortably — inside the zone at a size still worth reading. The
    /// segmenter asks this to decide how few pieces an ayah needs.
    public static func fitsWhole(_ arabic: String, largerText: Bool = false) -> Bool {
        guard let size = fittedSize(arabic) else { return false }
        return size >= boxPoints * comfortableFraction * (largerText ? 1.3 : 1)
    }

    public static func compose(
        arabic: String,
        translation: String,
        reference: String,
        largerText: Bool = false
    ) -> Composition? {
        IQFontRegistrar.register("Amiri-Bold")

        let side = boxPoints
        let inset = side * Zone.bleedGuard
        let width = side - inset * 2

        // Falls back to the hard minimum rather than bailing out: cramped is better than absent,
        // and an ayah that lands here should have been segmented before reaching this point.
        let pointSize = fittedSize(arabic)
            ?? side * hardMinimumFraction
        let attributes = attributes(pointSize: pointSize)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = renderScale

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            let text = arabic as NSString
            let zone = CGRect(
                x: inset,
                y: side * Zone.top,
                width: width,
                height: side * Zone.height
            )
            let bounds = text.boundingRect(
                with: CGSize(width: zone.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            // Optically centred in the square rather than top-aligned, so a two-line ayah sits in
            // the middle of the box instead of hugging its top edge.
            text.draw(
                with: CGRect(
                    x: zone.minX,
                    y: zone.minY + max(0, (zone.height - bounds.height) / 2),
                    width: zone.width,
                    height: min(bounds.height, zone.height)
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }

        return Composition(
            image: image.withRenderingMode(.alwaysOriginal),
            accessibilityLabel: "\(reference). \(translation)"
        )
    }

    // MARK: - Fitting

    /// Largest point size that sets this text in `maxLines` or fewer inside the zone, or nil if
    /// even the hard minimum overflows.
    private static func fittedSize(_ text: String) -> CGFloat? {
        let side = boxPoints
        let width = side - side * Zone.bleedGuard * 2
        let maxHeight = side * Zone.height

        // Starts near the full height of the zone: a very short ayah should be allowed to fill
        // the square on a single line.
        var size = maxHeight * 0.55
        let minimum = side * hardMinimumFraction
        while size >= minimum {
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes(pointSize: size),
                context: nil
            )
            let lines = Int((rect.height / (size * 1.75)).rounded(.up))
            if rect.height <= maxHeight && lines <= maxLines { return size }
            size -= 1
        }
        return nil
    }

    private static func attributes(pointSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineBreakMode = .byWordWrapping
        // 1.75 line-height. Amiri's vowel marks collide below this.
        paragraph.lineSpacing = pointSize * 0.75
        return [
            .font: UIFont(name: "Amiri-Bold", size: pointSize)
                ?? .systemFont(ofSize: pointSize, weight: .bold),
            .foregroundColor: cream,
            .paragraphStyle: paragraph
        ]
    }
}
