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
        let gold = UIColor(red: 0xC8 / 255, green: 0xB2 / 255, blue: 0x4E / 255, alpha: 1)
        let shieldBrown = UIColor(red: 0x25 / 255, green: 0x15 / 255, blue: 0x0C / 255, alpha: 1)
        // Divided at a waqf mark when the ayah cannot be legible whole — the pause the mushaf
        // itself prints, never a word or character budget.
        let segment = ShieldAyahProvider.segmented(for: store)

        // Only the Arabic goes in the icon. It is the one slot whose type we control, and the
        // one line that has to be big — so it gets the whole square rather than a third of it.
        // The reference and translation are legible at whatever size iOS picks for the text
        // slots, so they cost the Arabic nothing by living there.
        let composition = segment.flatMap {
            ShieldIconComposer.compose(
                arabic: $0.arabic,
                translation: $0.translation,
                reference: $0.reference
            )
        }

        // A tap refused for arriving too soon borrows the subtitle briefly. It used to replace
        // the whole thing for twenty seconds, which read as the ayah randomly disappearing.
        let recentlyRejected = store.ayahRejectedAt.map {
            Date().timeIntervalSince($0) < AppGroupStore.minimumAyahInterval
        } ?? false

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: shieldBrown,
            icon: composition?.image ?? Self.lockIcon(),
            // The meaning. It moved out of the icon so the Arabic could have the whole square —
            // and iOS sizes this slot legibly for free, which is exactly what the translation
            // needed and the Arabic could never get here.
            title: ShieldConfiguration.Label(
                text: segment?.translation ?? "",
                color: cream
            ),
            // Reference and progress. The rate now lives on the primary button, which states it
            // as a price where it actually lands.
            subtitle: ShieldConfiguration.Label(
                text: recentlyRejected
                    ? "Take a moment with it, then continue"
                    : ShieldAyahProvider.subtitleLine(
                        reference: segment?.reference ?? "",
                        store: store
                    ),
                color: gold
            ),
            // Names the destination and the price. Burying the action the user came for is what
            // makes a shield feel like a paywall.
            primaryButtonLabel: ShieldConfiguration.Label(
                text: ShieldAyahProvider.primaryLabel(appName: name, store: store),
                color: shieldBrown
            ),
            primaryButtonBackgroundColor: UIColor(red: 0xF0 / 255, green: 0xC2 / 255, blue: 0x4B / 255, alpha: 1),
            // Same gold family as the primary, so the two read as halves of one offer rather
            // than an offer and a dismissal.
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: segment?.secondaryLabel ?? "Read another ayah",
                color: gold
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
