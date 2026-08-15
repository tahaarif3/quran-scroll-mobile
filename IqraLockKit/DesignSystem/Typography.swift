import SwiftUI
import UIKit

public enum IQFontStyle: Equatable, Sendable {
    case wordmark
    case h1
    case h1PlanReady
    case h2
    case h3
    case subtitle
    case option
    case body
    case bodyStrong
    case caption
    case captionStrong
    case finePrint
    case button
    case ayah
    case ayahHome
    case translation
    case bismillah
    case stat
    case streak
    case greetingName

    public var size: CGFloat {
        switch self {
        case .wordmark: return 44
        case .h1: return 30
        case .h1PlanReady: return 36
        case .h2: return 24
        case .h3: return 20
        case .subtitle: return 17
        case .option: return 17
        case .body: return 15
        case .bodyStrong: return 15
        case .caption: return 14
        case .captionStrong: return 14
        case .finePrint: return 11.5
        case .button: return 20
        case .ayah: return 26
        case .ayahHome: return 27
        case .translation: return 15
        case .bismillah: return 24
        case .stat: return 28
        case .streak: return 52
        case .greetingName: return 24
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .wordmark, .h1, .h1PlanReady, .greetingName: return .black
        // `.heavy` is SwiftUI's 800 weight — i.e. Nunito-ExtraBold. There is no
        // `Font.Weight.extraBold`; the scale runs ultraLight/thin/light/regular/medium/
        // semibold/bold/heavy/black.
        case .option, .button, .stat, .finePrint: return .heavy
        // The "Strong" variants used to sit alongside their plain counterparts at .semibold,
        // which made them identical — every emphasis in the app that reached for `.bodyStrong`
        // or `.captionStrong` rendered exactly like body text. That is most of the missing bold
        // in the design comparison, not absent markup.
        case .h2, .h3, .streak, .ayah, .ayahHome, .bodyStrong, .captionStrong: return .bold
        case .subtitle, .body, .caption, .translation: return .semibold
        case .bismillah: return .regular
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .wordmark: return -1
        case .h1, .h1PlanReady: return -0.4
        case .h2: return -0.3
        default: return 0
        }
    }

    public var lineSpacingFactor: CGFloat {
        switch self {
        case .h1, .h1PlanReady: return 1.18
        case .ayah, .ayahHome: return 2.1
        case .body, .translation, .caption: return 1.47
        default: return 1.25
        }
    }

    public var usesAmiri: Bool {
        switch self {
        case .ayah, .ayahHome, .bismillah: return true
        default: return false
        }
    }

    public var postScriptName: String {
        if usesAmiri {
            switch self {
            case .bismillah: return "Amiri-Regular"
            default: return "Amiri-Bold"
            }
        }
        switch weight {
        case .black: return "Nunito-Black"
        case .heavy: return "Nunito-ExtraBold"
        case .bold: return "Nunito-Bold"
        case .semibold: return "Nunito-SemiBold"
        case .medium: return "Nunito-Medium"
        default: return "Nunito-Regular"
        }
    }

    public var font: Font {
        // `Font.custom` falls back to San Francisco when the PostScript name isn't registered
        // and reports nothing, so an unregistered family reads as "the design drifted" rather
        // than as a bug. Fail loudly in debug instead.
        assert(
            UIFont(name: postScriptName, size: size) != nil,
            "Font not registered: \(postScriptName). Check UIAppFonts reached the built bundle."
        )
        return .custom(postScriptName, size: size)
    }
}

public extension Font {
    static func iqra(_ style: IQFontStyle) -> Font { style.font }
}

public enum IQFontAudit {
    /// Every PostScript name the design system asks for.
    public static let requiredNames = [
        "Nunito-Regular", "Nunito-Medium", "Nunito-SemiBold",
        "Nunito-Bold", "Nunito-ExtraBold", "Nunito-Black",
        "Amiri-Regular", "Amiri-Bold"
    ]

    /// Names the running bundle cannot resolve. Empty means the fonts registered correctly.
    public static var missingNames: [String] {
        requiredNames.filter { UIFont(name: $0, size: 12) == nil }
    }

    /// Call once at launch. Prints nothing when the bundle is healthy.
    public static func verify(file: StaticString = #file, line: UInt = #line) {
        let missing = missingNames
        guard !missing.isEmpty else { return }
        print("""
        ⚠️ IqraLock: \(missing.count) font(s) not registered: \(missing.joined(separator: ", "))
           Registered families: \(UIFont.familyNames.filter { $0.contains("Nunito") || $0.contains("Amiri") })
           UIAppFonts is probably not reaching the bundle — check GENERATE_INFOPLIST_FILE in project.yml.
        """)
    }
}

public struct IQStyleModifier: ViewModifier {
    let style: IQFontStyle
    let color: Color

    public func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
            .lineSpacing(max(0, style.size * (style.lineSpacingFactor - 1.15)))
    }
}

public extension View {
    func iqraStyle(_ style: IQFontStyle, color: Color = IQColor.textInk) -> some View {
        modifier(IQStyleModifier(style: style, color: color))
    }
}
