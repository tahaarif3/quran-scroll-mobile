import CoreText
import Foundation
import UIKit

/// Draws the shield's icon — the one slot whose typography we control.
///
/// `ShieldConfiguration` offers five slots, and iOS owns the arrangement of all of them. The
/// title and subtitle are rendered at the system's own type at sizes we cannot influence, so
/// everything typographic lives here instead: reference, Arabic, hairline, translation. The two
/// text slots then get one short job each, short enough that neither can truncate.
public enum ShieldIconComposer {
    /// Square, always. iOS aspect-fits into a square box, so any other ratio throws away scale —
    /// the same pixels as a 3:1 banner render a third the height. 160pt is what current iPhones
    /// give; every dimension below is a percentage because that is not contractual.
    public static let boxPoints: CGFloat = 160
    public static let renderScale: CGFloat = 3

    /// Zone boundaries as fractions of the frame. Text is centred within each.
    private enum Zone {
        static let bleedGuard: CGFloat = 0.03
        static let referenceTop: CGFloat = 0.035
        static let arabicTop: CGFloat = 0.12
        static let arabicBottomShort: CGFloat = 0.68
        static let arabicBottomLong: CGFloat = 0.76
        static let hairlineShort: CGFloat = 0.72
        static let hairlineLong: CGFloat = 0.79
        static let translationTopShort: CGFloat = 0.76
        static let translationTopLong: CGFloat = 0.82
        static let translationBottom: CGFloat = 0.96
    }

    /// Floors, as fractions of frame height. Below these the text stops being readable, and
    /// shrinking further would be the same as hiding it.
    private enum Floor {
        static let arabic: CGFloat = 0.075
        static let translation: CGFloat = 0.036
    }

    private enum Palette {
        static let cream = UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 1)
        static let gold = UIColor(red: 0xC8 / 255, green: 0xB2 / 255, blue: 0x4E / 255, alpha: 1)
        static let hairline = UIColor(red: 0xC8 / 255, green: 0xB2 / 255, blue: 0x4E / 255, alpha: 0.45)
    }

    public struct Composition {
        public let image: UIImage
        /// The icon is an image, so its content is invisible to VoiceOver. This carries it.
        public let accessibilityLabel: String
    }

    /// Whether this Arabic sets inside the icon's zone without crossing its floor. The segmenter
    /// asks this to decide how few pieces an ayah needs.
    public static func fitsWhole(_ arabic: String, largerText: Bool = false) -> Bool {
        let side = boxPoints
        let width = side - side * Zone.bleedGuard * 2
        return fitArabic(
            arabic,
            width: width,
            maxHeight: side * (Zone.arabicBottomLong - Zone.arabicTop),
            floor: side * Floor.arabic * (largerText ? 1.3 : 1)
        ) != nil
    }

    public static func compose(
        arabic: String,
        translation: String,
        reference: String,
        largerText: Bool = false
    ) -> Composition? {
        IQFontRegistrar.register("Amiri-Bold")
        IQFontRegistrar.register("Nunito-SemiBold")

        let side = boxPoints
        let inset = side * Zone.bleedGuard
        let width = side - inset * 2

        // Fit order: set the Arabic as large as fits its zone in four lines or fewer. Only if it
        // does not fit does the translation give up its space — and the Arabic floor is never
        // crossed to make room.
        let arabicFloor = side * Floor.arabic * (largerText ? 1.3 : 1)
        let translationFloor = side * Floor.translation * (largerText ? 1.3 : 1)

        var arabicZone = (top: Zone.arabicTop, bottom: Zone.arabicBottomShort)
        var hairlineY = Zone.hairlineShort
        var translationZone = (top: Zone.translationTopShort, bottom: Zone.translationBottom)

        var arabicFit = fitArabic(
            arabic,
            width: width,
            maxHeight: side * (arabicZone.bottom - arabicZone.top),
            floor: arabicFloor
        )

        if arabicFit == nil {
            // Reclaim the translation's space rather than shrink the Arabic past its floor.
            arabicZone = (Zone.arabicTop, Zone.arabicBottomLong)
            hairlineY = Zone.hairlineLong
            translationZone = (Zone.translationTopLong, Zone.translationBottom)
            arabicFit = fitArabic(
                arabic,
                width: width,
                maxHeight: side * (arabicZone.bottom - arabicZone.top),
                floor: arabicFloor
            )
        }

        // Still no fit means the ayah needs segmenting at a waqf mark — see
        // ShieldAyahSegmenter. Rendering it anyway at the floor is the honest fallback until
        // segmentation has been reviewed: cramped, never cropped.
        let arabicAttributes = arabicFit ?? arabicAttributes(pointSize: arabicFloor)

        let translationAttributes = fitTranslation(
            translation,
            width: width,
            maxHeight: side * (translationZone.bottom - translationZone.top),
            floor: translationFloor,
            ceiling: side * 0.055
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = renderScale

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { context in
            (reference as NSString).draw(
                with: CGRect(x: inset, y: side * Zone.referenceTop, width: width, height: side * 0.07),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: referenceAttributes(pointSize: side * 0.045),
                context: nil
            )

            drawCentred(
                arabic,
                in: CGRect(
                    x: inset,
                    y: side * arabicZone.top,
                    width: width,
                    height: side * (arabicZone.bottom - arabicZone.top)
                ),
                attributes: arabicAttributes
            )

            let rule = CGRect(x: side * 0.28, y: side * hairlineY, width: side * 0.44, height: 1 / renderScale)
            context.cgContext.setFillColor(Palette.hairline.cgColor)
            context.cgContext.fill(rule)

            drawCentred(
                translation,
                in: CGRect(
                    x: inset,
                    y: side * translationZone.top,
                    width: width,
                    height: side * (translationZone.bottom - translationZone.top)
                ),
                attributes: translationAttributes
            )
        }

        return Composition(
            image: image.withRenderingMode(.alwaysOriginal),
            accessibilityLabel: "\(reference). \(translation)"
        )
    }

    // MARK: - Fitting

    /// Largest size whose text sets in four lines or fewer inside the zone, or nil if even the
    /// floor overflows.
    private static func fitArabic(
        _ text: String,
        width: CGFloat,
        maxHeight: CGFloat,
        floor: CGFloat
    ) -> [NSAttributedString.Key: Any]? {
        var size = maxHeight * 0.62
        while size >= floor {
            let attributes = arabicAttributes(pointSize: size)
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let lineHeight = size * 1.75
            let lines = Int((rect.height / lineHeight).rounded(.up))
            if rect.height <= maxHeight && lines <= 4 { return attributes }
            size -= 1
        }
        return nil
    }

    private static func fitTranslation(
        _ text: String,
        width: CGFloat,
        maxHeight: CGFloat,
        floor: CGFloat,
        ceiling: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        var size = ceiling
        while size > floor {
            let attributes = translationAttributes(pointSize: size)
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            if rect.height <= maxHeight { return attributes }
            size -= 0.5
        }
        return translationAttributes(pointSize: floor)
    }

    // MARK: - Attributes

    private static func arabicAttributes(pointSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineBreakMode = .byWordWrapping
        // 1.75 line-height. Amiri's vowel marks collide below this.
        paragraph.lineSpacing = pointSize * 0.75
        return [
            .font: UIFont(name: "Amiri-Bold", size: pointSize)
                ?? .systemFont(ofSize: pointSize, weight: .bold),
            .foregroundColor: Palette.cream,
            .paragraphStyle: paragraph
        ]
    }

    private static func translationAttributes(pointSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = pointSize * 0.25
        return [
            .font: UIFont(name: "Nunito-SemiBold", size: pointSize)
                ?? .systemFont(ofSize: pointSize, weight: .semibold),
            .foregroundColor: Palette.cream.withAlphaComponent(0.88),
            .paragraphStyle: paragraph
        ]
    }

    private static func referenceAttributes(pointSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return [
            .font: UIFont(name: "Nunito-SemiBold", size: pointSize)
                ?? .systemFont(ofSize: pointSize, weight: .semibold),
            .foregroundColor: Palette.gold,
            .paragraphStyle: paragraph
        ]
    }

    /// Vertically centres within the zone rather than top-aligning, so a short ayah sits in the
    /// middle of its space instead of hugging the reference above it.
    private static func drawCentred(
        _ text: String,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let ns = text as NSString
        let bounds = ns.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let y = rect.minY + max(0, (rect.height - bounds.height) / 2)
        ns.draw(
            with: CGRect(x: rect.minX, y: y, width: rect.width, height: min(bounds.height, rect.height)),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }
}
