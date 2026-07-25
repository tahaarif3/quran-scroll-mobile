import SwiftUI

/// Palette **1c** — Sand + Gold/Olive.
/// Values follow the design-handoff README token table (authoritative when present in-repo).
/// Note: `design_handoff_iqralock_onboarding/` was not checked into this repository;
/// tokens below are reconstructed from the implementation plan's explicit hex values
/// and standard 1c sand/olive pairings. Re-diff against the README on Mac before ship.
public enum IQColor {
    // MARK: Backgrounds
    public static let bgSand = Color(hex: 0xF4E8D0)
    public static let bgSandDeep = Color(hex: 0xEDE0C4)
    public static let bgReader = Color(hex: 0xF7EDD8)
    public static let bgReaderBar = Color(hex: 0xE8DDC2)
    public static let bgCard = Color.white
    public static let bgDark = Color(hex: 0x3E3521)
    public static let bgShield = Color(hex: 0x2A1810)
    public static let oliveTint = Color(hex: 0xF3F0DE)

    // MARK: Brand / accent
    public static let olive = Color(hex: 0x7A5A16)
    public static let oliveDeep = Color(hex: 0x5C4410)
    public static let gold = Color(hex: 0xC8B24E)
    public static let goldBright = Color(hex: 0xF0C24B)
    public static let brand = Color(hex: 0x7A5A16)
    public static let brandHighlight = Color(hex: 0xB8860B)

    // MARK: Text
    public static let textPrimary = Color(hex: 0x2B2521)
    public static let textSecondary = Color(hex: 0x6B625A) // muted2 — prefer for body <18pt (WCAG)
    public static let textMuted = Color(hex: 0x8A8078) // large text only per contrast note
    public static let textOnDark = Color(hex: 0xF7EDD8)
    public static let textOnGold = Color(hex: 0x2B2521)
    public static let textInverse = Color.white

    // MARK: Borders / chrome
    public static let borderSubtle = Color(hex: 0x2B2521).opacity(0.10)
    public static let borderOlive = Color(hex: 0x7A5A16)
    public static let ringEmpty = Color(hex: 0xCDC4B6)
    public static let tabInactive = Color(hex: 0xB3A585)
    public static let chartNeutral = Color(hex: 0xE3D6C0)
    public static let hairline = Color(hex: 0x2B2521).opacity(0.08)

    // MARK: Buttons — disabled
    public static let buttonDisabledFace = Color(hex: 0xDDD2C2)
    public static let buttonDisabledEdge = Color(hex: 0xCABCA8)
    public static let buttonDisabledText = Color(hex: 0xA99883)

    // MARK: Gradients
    public static let iconGradientTop = Color(hex: 0x6B3F1E)
    public static let iconGradientBottom = Color(hex: 0x38200F)

    public static var appIconGradient: LinearGradient {
        LinearGradient(
            colors: [iconGradientTop, iconGradientBottom],
            startPoint: UnitPoint(x: 0.2, y: 0),
            endPoint: UnitPoint(x: 0.8, y: 1)
        )
    }

    public static var welcomeRadial: RadialGradient {
        RadialGradient(
            colors: [Color(hex: 0xFBF3E4), bgSand, bgSandDeep],
            center: .top,
            startRadius: 20,
            endRadius: 520
        )
    }

    public static var lockRadial: RadialGradient {
        RadialGradient(
            colors: [Color(hex: 0x4A2E18), bgShield],
            center: .center,
            startRadius: 10,
            endRadius: 320
        )
    }
}

public enum IQRadius {
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 18
    public static let xl: CGFloat = 24
    public static let pill: CGFloat = 999
}

public enum IQSpace {
    public static let gutter: CGFloat = 24
    public static let gutterWide: CGFloat = 26
    public static let ctaBottom: CGFloat = 26
    public static let section: CGFloat = 28
    public static let stack: CGFloat = 12
    public static let stackTight: CGFloat = 8
}

public enum IQShadow {
    /// Hard bottom edge for chunky buttons: 0 6px 0
    public static let chunkyOffset: CGFloat = 6
    public static let card = ShadowToken(color: Color.black.opacity(0.06), radius: 12, y: 4)
    public static let soft = ShadowToken(color: Color.black.opacity(0.08), radius: 16, y: 8)
}

public struct ShadowToken: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat
}

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
