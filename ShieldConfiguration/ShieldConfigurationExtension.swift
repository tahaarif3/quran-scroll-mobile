import ManagedSettings
import ManagedSettingsUI
import UIKit
import IqraLockKit

/// OS shield approximation of screen 3d.
/// Full SwiftUI 3d is shown in-app; the system shield only supports ShieldConfiguration fields.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let store = AppGroupStore.shared
        store.ensureCurrentDay()
        let name = application.localizedDisplayName ?? "This app"
        analyticsShown()

        let cream = UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 1)
        let ayah = ShieldAyahProvider.ayah(for: store)

        // The ayah goes in the icon, not the subtitle, because the subtitle has no font control
        // and truncates. Falling back to the lock mark keeps the shield coherent if the database
        // cannot be opened from the extension.
        let icon = ayah.flatMap { ShieldAyahProvider.arabicImage(for: $0, color: cream) }
            ?? Self.lockIcon()

        // Subtitle carries the translation and the progress — Latin text the system renders
        // predictably. Reference included so the ayah can be looked up.
        let subtitle: String
        if let ayah {
            // The "too fast" nudge is appended, not substituted. Replacing the whole subtitle
            // hid the translation for twenty seconds after any quick tap, which read as the
            // translation randomly failing to appear.
            let recentlyRejected = store.ayahRejectedAt.map {
                Date().timeIntervalSince($0) < AppGroupStore.minimumAyahInterval
            } ?? false
            let tail = recentlyRejected
                ? "Take a moment with it, then continue."
                : ShieldAyahProvider.progressLine(for: store)
            subtitle = "\"\(ayah.translationEn)\"\n— \(ayah.verseKey)\n\n\(tail)"
        } else {
            subtitle = store.shieldSubtitle()
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0x25 / 255, green: 0x15 / 255, blue: 0x0C / 255, alpha: 1),
            icon: icon,
            title: ShieldConfiguration.Label(
                text: "\(name) is locked",
                color: cream
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor(red: 0xC8 / 255, green: 0xB2 / 255, blue: 0x4E / 255, alpha: 1)
            ),
            // Both buttons read the ayah. One spends it on a timed window, the other banks it
            // and serves another — so "read more" needs no third button.
            // Emergency passes moved into the app; they were too easy to reach from here.
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Continue to app (\(store.ayahUnlockMinutes) min)",
                color: UIColor(red: 0x2B / 255, green: 0x25 / 255, blue: 0x21 / 255, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0xF0 / 255, green: 0xC2 / 255, blue: 0x4B / 255, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Read another ayah",
                color: cream.withAlphaComponent(0.85)
            )
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    private func analyticsShown() {
        // Extensions cannot reliably ship analytics; App Group flag for app to pick up.
        UserDefaults(suiteName: AppGroupID.identifier)?.set(true, forKey: "pending_shield_shown")
    }

    private static func lockIcon() -> UIImage? {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0x6B / 255, green: 0x3F / 255, blue: 0x1E / 255, alpha: 1).cgColor,
                UIColor(red: 0x38 / 255, green: 0x20 / 255, blue: 0x0F / 255, alpha: 1).cgColor
            ]
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width * 0.2, y: 0),
                    end: CGPoint(x: size.width * 0.8, y: size.height),
                    options: []
                )
            }
            let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .bold)
            if let lock = UIImage(systemName: "lock.fill", withConfiguration: config)?
                .withTintColor(UIColor(red: 0xF0 / 255, green: 0xC2 / 255, blue: 0x4B / 255, alpha: 1), renderingMode: .alwaysOriginal) {
                let rect = CGRect(x: (size.width - 54) / 2, y: (size.height - 54) / 2, width: 54, height: 54)
                lock.draw(in: rect)
            }
        }
    }
}
