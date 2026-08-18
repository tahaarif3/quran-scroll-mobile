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
        // Divided when the ayah is too long for the title slot. A character budget decides
        // *whether* to divide; only a printed waqf mark decides *where*.
        let segment = ShieldAyahProvider.segmented(for: store)

        // A tap refused for arriving too soon borrows the subtitle briefly. It used to replace
        // the whole thing for twenty seconds, which read as the ayah randomly disappearing.
        let recentlyRejected = store.ayahRejectedAt.map {
            Date().timeIntervalSince($0) < AppGroupStore.minimumAyahInterval
        } ?? false

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: shieldBrown,
            icon: Self.lockIcon(),
            // The Arabic, in the largest slot the shield has.
            //
            // It was drawn into the icon before, which gave us the typography — our own Amiri
            // face, our own sizing — and cost us the thing that mattered more. iOS renders that
            // icon small whatever is in it, so the Arabic came out smaller than the English
            // sitting in a plain system label beneath it. The system font renders Uthmani text
            // correctly if not beautifully, and being read beats being set well.
            title: ShieldConfiguration.Label(
                text: segment?.arabic ?? "",
                color: cream
            ),
            // Translation, then the reference under it. The rate the user is paying is on the
            // primary button, where it reads as a price at the point it is paid.
            subtitle: ShieldConfiguration.Label(
                text: recentlyRejected
                    ? "Take a moment with it, then continue"
                    : segment?.subtitle ?? "",
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
