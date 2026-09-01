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

        let segment = ShieldAyahProvider.segmented(for: store)
        let recentlyRejected = store.ayahRejectedAt.map {
            Date().timeIntervalSince($0) < AppGroupStore.minimumAyahInterval
        } ?? false
        let content = ShieldLayoutPresentation.make(
            mode: store.shieldLayoutMode,
            segment: segment,
            appName: name,
            store: store,
            recentlyRejected: recentlyRejected
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: shieldBrown,
            icon: Self.lockIcon(),
            title: ShieldConfiguration.Label(text: content.title, color: cream),
            subtitle: ShieldConfiguration.Label(text: content.subtitle, color: gold),
            primaryButtonLabel: ShieldConfiguration.Label(text: content.primaryButton, color: shieldBrown),
            primaryButtonBackgroundColor: UIColor(red: 0xF0 / 255, green: 0xC2 / 255, blue: 0x4B / 255, alpha: 1),
            secondaryButtonLabel: content.secondaryButton.map {
                ShieldConfiguration.Label(text: $0, color: gold)
            }
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    private func analyticsShown() {
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
