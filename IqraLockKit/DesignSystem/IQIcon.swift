import SwiftUI
import UIKit

private final class IqraLockKitBundleToken {}

public extension Bundle {
    /// The framework's own bundle. Icons ship with IqraLockKit rather than the app so that the
    /// shield extensions — which link the framework but are separate bundles — resolve them too.
    static let iqraLockKit = Bundle(for: IqraLockKitBundleToken.self)
}

/// The app's icon set: Microsoft Fluent Emoji 3D renders, MIT licensed.
///
/// These replace system emoji throughout onboarding. Apple's glyphs are redrawn between iOS
/// releases and are unavailable on Android, web and in App Store screenshots, so a design that
/// leans on them drifts without any code changing. See `Resources/LICENSE-fluent-emoji.txt`.
public enum IQIcon: String, CaseIterable, Sendable {
    case book = "iq-book"
    case phoneOff = "iq-phone-off"
    case dua = "iq-dua"
    case bulb = "iq-bulb"
    case seed = "iq-seed"
    case mosque = "iq-mosque"
    case heart = "iq-heart"
    case sparkle = "iq-sparkle"
    case arabicLetter = "iq-arabic-letter"
    case speak = "iq-speak"
    case star = "iq-star"
    case globe = "iq-globe"
    case moon = "iq-moon"
    case calendar = "iq-calendar"
    case flame = "iq-flame"
    case man = "iq-man"
    case woman = "iq-woman"
    case hourglass = "iq-hourglass"
    case lock = "iq-lock"
    case bookmark = "iq-bookmark"
    case clock = "iq-clock"
    case people = "iq-people"
    case mindBlown = "iq-mind-blown"

    /// Row icons draw at 26pt inside a fixed 28pt column so labels align down the list.
    public static let rowSize: CGFloat = 26
    public static let rowColumnWidth: CGFloat = 28
    /// Hero screens (reveal, reframe, promise) draw the icon large and centred.
    public static let heroSize: CGFloat = 72

    public var image: Image {
        Image(rawValue, bundle: .iqraLockKit)
    }

    public func view(size: CGFloat = IQIcon.rowSize) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Icons that trail a headline read as part of the sentence, so they have to sit on the text
/// baseline rather than on their own line. `Text(Image:)` composes inline but ignores
/// `.resizable()`, so the raster is scaled once and cached per (icon, size).
private enum InlineIconCache {
    // NSCache rather than a dictionary behind a lock: it is already thread-safe and, being a
    // `let`, needs no concurrency annotation. `nonisolated(unsafe)` would not compile under the
    // project's Swift 5.9 language mode.
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for icon: IQIcon, pointSize: CGFloat) -> Image? {
        let key = "\(icon.rawValue)@\(Int(pointSize.rounded()))" as NSString
        if let cached = cache.object(forKey: key) {
            return Image(uiImage: cached)
        }
        guard let source = UIImage(named: icon.rawValue, in: .iqraLockKit, with: nil) else {
            return nil
        }
        let target = CGSize(width: pointSize, height: pointSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let scaled = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        cache.setObject(scaled, forKey: key)
        return Image(uiImage: scaled)
    }
}

public extension IQIcon {
    /// Baseline-aligned image for use inside a `Text` run.
    func inlineText(pointSize: CGFloat) -> Text {
        guard let image = InlineIconCache.image(for: self, pointSize: pointSize) else {
            return Text("")
        }
        return Text(image)
    }
}

public struct IQIconView: View {
    let icon: IQIcon
    let size: CGFloat

    public init(_ icon: IQIcon, size: CGFloat = IQIcon.rowSize) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        icon.view(size: size)
    }
}

#if DEBUG
public extension IQIcon {
    /// Cases with no matching image in the framework bundle. Empty means the catalogue is intact.
    static var missingAssets: [IQIcon] {
        allCases.filter { UIImage(named: $0.rawValue, in: .iqraLockKit, with: nil) == nil }
    }
}
#endif
