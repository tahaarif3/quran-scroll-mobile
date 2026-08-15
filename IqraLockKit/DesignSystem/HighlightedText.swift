import SwiftUI

/// Parses `**…**` spans into brand-colored bold text.
/// Use `highlight: IQColor.brandGold` for numeric reveals ("25 years").
public struct HighlightedText: View {
    let source: String
    let baseStyle: IQFontStyle
    let baseColor: Color
    let highlightColor: Color
    let alignment: TextAlignment
    /// Rendered inline after the last word, replacing what used to be a trailing system emoji.
    let trailingIcon: IQIcon?

    public init(
        _ source: String,
        style: IQFontStyle = .h1,
        color: Color = IQColor.textInk,
        highlight: Color = IQColor.brandPrimary,
        alignment: TextAlignment = .leading,
        trailingIcon: IQIcon? = nil
    ) {
        self.source = source
        self.baseStyle = style
        self.baseColor = color
        self.highlightColor = highlight
        self.alignment = alignment
        self.trailingIcon = trailingIcon
    }

    public var body: some View {
        composedText
            // Deliberately no `.font()` here. Every run already carries its own — plain runs the
            // base style, highlighted runs Nunito-Black — and a view-level font flattens all of
            // them to a single weight. The `**bold**` spans were parsed correctly and then
            // erased at render, which is why none of the emphasis in the design showed up.
            .tracking(baseStyle.tracking)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private var composedText: Text {
        let base = Text(attributed)
        guard let trailingIcon else { return base }
        // The separator carries the base font explicitly, since there is no view-level font to
        // fall back on any more.
        return base
            + Text(" ").font(baseStyle.font)
            + trailingIcon.inlineText(pointSize: baseStyle.size)
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
        guard let regex = try? NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#, options: []) else {
            return AttributedString(source)
        }
        let ns = source as NSString
        let full = NSRange(location: 0, length: ns.length)
        var cursor = 0

        func appendPlain(_ string: String, highlight: Bool) {
            var chunk = AttributedString(string)
            chunk.foregroundColor = highlight ? highlightColor : baseColor
            chunk.font = highlight
                ? Font.custom("Nunito-Black", size: baseStyle.size)
                : baseStyle.font
            result.append(chunk)
        }

        for match in regex.matches(in: source, options: [], range: full) {
            let matchRange = match.range
            if matchRange.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: matchRange.location - cursor))
                appendPlain(plain, highlight: false)
            }
            if match.numberOfRanges > 1 {
                appendPlain(ns.substring(with: match.range(at: 1)), highlight: true)
            }
            cursor = matchRange.location + matchRange.length
        }
        if cursor < ns.length {
            appendPlain(ns.substring(from: cursor), highlight: false)
        }
        return result
    }
}
