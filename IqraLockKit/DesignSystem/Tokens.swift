import SwiftUI

/// Palette **1c** — Sand + Gold/Olive.
/// Authoritative values from the design-handoff README token table.
public enum IQColor {
    // MARK: Backgrounds
    public static let bgSand = Color(hex: 0xF4E8D0)
    public static let bgReader = Color(hex: 0xF7EDD8)
    public static let bgCard = Color(hex: 0xFFFFFF)
    public static let bgDark = Color(hex: 0x3E3521)
    public static let oliveTint = Color(hex: 0xF3F0DE)

    // MARK: Text
    public static let textInk = Color(hex: 0x2B2521)
    public static let textMuted = Color(hex: 0x8A8078)
    public static let textMuted2 = Color(hex: 0x6B625A)
    public static let textFaint = Color(hex: 0x9A9088)
    public static let textInverse = Color.white
    public static let textOnDark = Color(hex: 0xF7EDD8)
    public static let textOnGold = Color(hex: 0x2B2521)

    // Aliases used across views
    public static let textPrimary = textInk
    public static let textSecondary = textMuted2

    // MARK: Brand
    public static let brandPrimary = Color(hex: 0x7A5A16)
    public static let brandPrimaryShadow = Color(hex: 0x513A0D)
    public static let brandGold = Color(hex: 0xA6801F)
    public static let olive = brandPrimary
    public static let oliveDeep = brandPrimaryShadow
    public static let brand = brandPrimary
    public static let brandHighlight = brandPrimary
    public static let goldHighlight = brandGold

    // MARK: Accent
    public static let accentOlive = Color(hex: 0x6F7A34)
    public static let accentGoldOnDark = Color(hex: 0xC8B24E)
    public static let gold = accentGoldOnDark
    public static let goldBright = Color(hex: 0xF0C24B)
    public static let borderOlive = accentOlive
    public static let oliveAccent = accentOlive

    // MARK: Tracks / chrome
    public static let track = Color(hex: 0xE6D9BC)
    public static let trackReader = Color(hex: 0xE8DDC2)
    public static let bgReaderBar = trackReader
    public static let star = Color(hex: 0xC79A3A)
    public static let savePill = Color(hex: 0xECE3C4)
    public static let tabInactive = Color(hex: 0xB3A585)
    public static let tabActive = brandPrimary
    public static let radioEmpty = Color(hex: 0xCDC4B6)
    public static let ringEmpty = radioEmpty
    public static let chartNeutral = Color(hex: 0xE3D6C0)
    public static let hairline = Color(hex: 0x2B2521).opacity(0.08)
    public static let borderSubtle = Color(hex: 0x2B2521).opacity(0.10)

    // MARK: Disabled button
    public static let buttonDisabledFace = Color(hex: 0xDDD2C2)
    public static let buttonDisabledEdge = Color(hex: 0xCABCA8)
    public static let buttonDisabledText = Color(hex: 0xA99883)

    // MARK: App icon
    public static let iconGradientTop = Color(hex: 0x6B3F1E)
    public static let iconGradientBottom = Color(hex: 0x38200F)
    public static let iconGlyph = Color(hex: 0xF3E4C4)
    public static let iconCrescent = Color(hex: 0xE7B85C)

    // MARK: Lock screen
    public static let lockGradientTop = Color(hex: 0x3A2114)
    public static let lockGradientBottom = Color(hex: 0x25150C)
    public static let bgShield = lockGradientBottom
    public static let bgShieldCard = Color.white.opacity(0.10)
    public static let lockCTA = Color(hex: 0xF0C24B)
    public static let lockCTAShadow = Color(hex: 0xC99A2C)

    // MARK: Gradients
    public static var appIconGradient: LinearGradient {
        LinearGradient(
            colors: [iconGradientTop, iconGradientBottom],
            startPoint: UnitPoint(x: 0.15, y: 0),
            endPoint: UnitPoint(x: 0.85, y: 1) // ~150°
        )
    }

    /// Welcome only: warm radial #EACB84 → #F4E8D0.
    ///
    /// Mirrors the design's `radial-gradient(120% 78% at 50% 12%, #EACB84, #F4E8D0 55%)`.
    /// The gold has to be fully resolved to sand by ~55% down the screen, so the radius is
    /// driven off the container height rather than fixed — a constant that reads correctly on
    /// a 6.7" device leaves gold across the whole of an SE.
    public static func welcomeRadial(height: CGFloat) -> RadialGradient {
        RadialGradient(
            colors: [Color(hex: 0xEACB84), bgSand],
            center: UnitPoint(x: 0.5, y: 0.12),
            startRadius: 0,
            endRadius: max(140, height * 0.55)
        )
    }

    public static var lockRadial: RadialGradient {
        RadialGradient(
            colors: [lockGradientTop, lockGradientBottom],
            center: .center,
            startRadius: 8,
            endRadius: 340
        )
    }
}

public enum IQRadius {
    public static let option: CGFloat = 16.5
    public static let card: CGFloat = 18
    public static let button: CGFloat = 20
    public static let appIcon: CGFloat = 26
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 18
    public static let xl: CGFloat = 22
    public static let pill: CGFloat = 999
}

public enum IQSpace {
    public static let gutter: CGFloat = 24
    public static let gutterWide: CGFloat = 26
    public static let ctaBottom: CGFloat = 24
    public static let optionGap: CGFloat = 13
    public static let section: CGFloat = 28
    public static let stack: CGFloat = 12
    public static let stackTight: CGFloat = 8
    public static let buttonHeight: CGFloat = 60
}

public enum IQShadow {
    /// Hard offset 0 6px 0 — signature chunky button
    public static let chunkyOffset: CGFloat = 6
    public static let card = ShadowToken(color: Color.black.opacity(0.05), radius: 14, y: 4)
    public static let elevated = ShadowToken(color: Color.black.opacity(0.07), radius: 20, y: 8)
    public static let appIcon = ShadowToken(color: Color(hex: 0x3A2011).opacity(0.4), radius: 26, y: 14)
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
