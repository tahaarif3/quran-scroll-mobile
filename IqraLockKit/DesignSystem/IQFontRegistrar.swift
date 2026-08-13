import CoreText
import Foundation
import UIKit

/// Registers the bundled fonts at runtime instead of relying on `UIAppFonts`.
///
/// `UIAppFonts` only registers fonts found in the **main app bundle**, and only when the
/// filenames in the plist match the bundle layout exactly — a `Fonts/` subdirectory needs the
/// prefix, a flat copy must not have it. IqraLockKit owns the type system and ships the fonts,
/// so it registers them itself. That removes three failure modes at once: which target copied
/// the files, whether they landed flat or nested, and the fact that app extensions have their
/// own bundles and never consult the app's `UIAppFonts` at all.
///
/// This is not belt-and-braces. An unregistered font took the app down on launch: UIKit was
/// handed `NSNull` for a tab-bar title font and called a font selector on it.
public enum IQFontRegistrar {
    private static let lock = NSLock()
    private static var hasRegistered = false
    private static var registeredFiles: Set<String> = []

    /// Registers a single font file by name.
    ///
    /// The shield extension is relaunched for every presentation and only ever needs Amiri.
    /// Registering all eight faces there cost enough to make "Read another ayah" feel laggy.
    public static func register(_ fileName: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !registeredFiles.contains(fileName), !hasRegistered else { return }
        registeredFiles.insert(fileName)
        for bundle in [Bundle.iqraLockKit, Bundle.main] {
            for subdirectory in [nil, "Fonts"] as [String?] {
                if let url = bundle.url(
                    forResource: fileName,
                    withExtension: "ttf",
                    subdirectory: subdirectory
                ) {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                    return
                }
            }
        }
    }

    /// Idempotent and cheap after the first call. Safe to call from any thread.
    public static func registerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !hasRegistered else { return }
        hasRegistered = true

        for bundle in [Bundle.iqraLockKit, Bundle.main] {
            // Both layouts: flattened into the bundle root, and preserved under Fonts/.
            for subdirectory in [nil, "Fonts"] as [String?] {
                let urls = bundle.urls(
                    forResourcesWithExtension: "ttf",
                    subdirectory: subdirectory
                ) ?? []
                for url in urls {
                    // Fails harmlessly when the font is already registered — by UIAppFonts, or
                    // by an earlier call from an extension sharing this process.
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }
}

public extension UIFont {
    /// A registered custom font, or a weight-matched system fallback.
    ///
    /// Never returns nil. `UIFont(name:size:)` returning nil into a dictionary literal is what
    /// crashed the app: `as Any` bridges the nil Optional to `NSNull`, UIKit stores it as the
    /// font attribute, and the next layout pass sends a font message to `NSNull` and aborts.
    static func iqra(_ postScriptName: String, size: CGFloat, fallback: UIFont.Weight = .semibold) -> UIFont {
        IQFontRegistrar.registerIfNeeded()
        return UIFont(name: postScriptName, size: size)
            ?? .systemFont(ofSize: size, weight: fallback)
    }
}
