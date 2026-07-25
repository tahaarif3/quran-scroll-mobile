import SwiftUI

/// Parses `**…**` spans into brand-colored bold text.
/// SwiftUI markdown cannot color spans; this keeps onboarding copy declarative.
public struct HighlightedText: View {
    let source: String
    let baseStyle: IQFontStyle
    let baseColor: Color
    let highlightColor: Color
    let alignment: TextAlignment

    public init(
        _ source: String,
        style: IQFontStyle = .h1,
        color: Color = IQColor.textPrimary,
        highlight: Color = IQColor.brandHighlight,
        alignment: TextAlignment = .leading
    ) {
        self.source = source
        self.baseStyle = style
        self.baseColor = color
        self.highlightColor = highlight
        self.alignment = alignment
    }

    public var body: some View {
        Text(attributed)
            .font(baseStyle.font)
            .tracking(baseStyle.tracking)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    public var attributed: AttributedString {
        Self.makeAttributed(
            source: source,
            baseStyle: baseStyle,
            baseColor: baseColor,
            highlightColor: highlightColor
        )
    }

    public static func makeAttributed(
        source: String,
        baseStyle: IQFontStyle,
        baseColor: Color,
        highlightColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        let pattern = #"\*\*(.+?)\*\*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return AttributedString(source)
        }
        let ns = source as NSString
        let full = NSRange(location: 0, length: ns.length)
        var cursor = 0
        let matches = regex.matches(in: source, options: [], range: full)

        func appendPlain(_ string: String, highlight: Bool) {
            var chunk = AttributedString(string)
            chunk.foregroundColor = highlight ? highlightColor : baseColor
            chunk.font = highlight
                ? Font.custom("Nunito-Black", size: baseStyle.size)
                : baseStyle.font
            result.append(chunk)
        }

        for match in matches {
            let matchRange = match.range
            if matchRange.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: matchRange.location - cursor))
                appendPlain(plain, highlight: false)
            }
            if match.numberOfRanges > 1 {
                let inner = ns.substring(with: match.range(at: 1))
                appendPlain(inner, highlight: true)
            }
            cursor = matchRange.location + matchRange.length
        }
        if cursor < ns.length {
            appendPlain(ns.substring(from: cursor), highlight: false)
        }
        return result
    }
}
