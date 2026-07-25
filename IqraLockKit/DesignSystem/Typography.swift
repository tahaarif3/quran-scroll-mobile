import SwiftUI

public enum IQFontStyle: Equatable, Sendable {
    case wordmark
    case h1
    case h2
    case h3
    case body
    case bodyStrong
    case caption
    case captionStrong
    case button
    case buttonSmall
    case ayah
    case bismillah
    case stat
    case streak

    public var size: CGFloat {
        switch self {
        case .wordmark: return 42
        case .h1: return 32
        case .h2: return 26
        case .h3: return 20
        case .body: return 16
        case .bodyStrong: return 16
        case .caption: return 13
        case .captionStrong: return 13
        case .button: return 17
        case .buttonSmall: return 15
        case .ayah: return 26
        case .bismillah: return 28
        case .stat: return 28
        case .streak: return 52
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .wordmark, .h1: return .black          // 900
        case .h2, .button, .stat: return .extraBold // 800
        case .h3, .bodyStrong, .buttonSmall, .streak: return .bold // 700
        case .captionStrong: return .semibold       // 600
        case .body, .caption: return .medium        // 500
        case .ayah, .bismillah: return .regular     // Amiri 400
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .wordmark: return -1
        case .h1: return -0.4
        case .h2: return -0.3
        default: return 0
        }
    }

    public var usesAmiri: Bool {
        self == .ayah || self == .bismillah
    }

    public var postScriptName: String {
        if usesAmiri {
            return weight == .bold ? "Amiri-Bold" : "Amiri-Regular"
        }
        switch weight {
        case .black: return "Nunito-Black"
        case .extraBold: return "Nunito-ExtraBold"
        case .bold: return "Nunito-Bold"
        case .semibold: return "Nunito-SemiBold"
        case .medium: return "Nunito-Medium"
        default: return "Nunito-Regular"
        }
    }

    public var font: Font {
        .custom(postScriptName, size: size)
    }
}

public extension Font {
    static func iqra(_ style: IQFontStyle) -> Font { style.font }
}

public struct IQStyleModifier: ViewModifier {
    let style: IQFontStyle
    let color: Color

    public func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
    }
}

public extension View {
    func iqraStyle(_ style: IQFontStyle, color: Color = IQColor.textPrimary) -> some View {
        modifier(IQStyleModifier(style: style, color: color))
    }
}
