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

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0x2A / 255, green: 0x18 / 255, blue: 0x10 / 255, alpha: 1),
            icon: Self.lockIcon(),
            title: ShieldConfiguration.Label(
                text: "\(name) is locked",
                color: UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: store.shieldSubtitle(),
                color: UIColor(red: 0xC8 / 255, green: 0xB2 / 255, blue: 0x4E / 255, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Read now to unlock",
                color: UIColor(red: 0x2B / 255, green: 0x25 / 255, blue: 0x21 / 255, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0xF0 / 255, green: 0xC2 / 255, blue: 0x4B / 255, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Use emergency pass (\(store.emergencyPassesRemaining) left)",
                color: UIColor(red: 0xF7 / 255, green: 0xED / 255, blue: 0xD8 / 255, alpha: 0.85)
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
