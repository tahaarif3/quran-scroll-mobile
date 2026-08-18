import Foundation

/// Splits an ayah too long for the shield into pieces that pause where the mushaf pauses.
///
/// Ayat al-Kursi cannot fit the shield's title slot, and that slot truncates rather than
/// shrinking — so the choice is to divide it or to cut it off mid-word. It ends at a waqf mark
/// instead, a pause the mushaf itself prints, and the reference line says which piece this is.
///
/// A budget decides *whether* to divide. Only a waqf mark decides *where*: breaks happen at
/// these marks and nowhere else. An ayah carrying none is returned whole and allowed to
/// truncate — losing the tail of a verse is bad, and inventing a pause in Qur'anic text that
/// does not contain one is worse.
public enum ShieldAyahSegmenter {
    /// The pause marks of the mushaf. Breaking anywhere else would invent a pause the text does
    /// not contain.
    public static let waqfMarks: Set<Character> = [
        "\u{06D6}", // ṣalā — prefer to continue
        "\u{06D7}", // qalā — prefer to stop
        "\u{06D8}", // sakta — brief pause without breath
        "\u{06DA}", // jīm — permissible pause
        "\u{06DB}", // three dots — pause at one of a pair, not both
        "\u{06DE}"  // rubʿ — end of a quarter hizb
    ]

    /// Most segments an ayah is ever broken into. Beyond this the reading is so fragmented that
    /// serving the whole thing cramped is the better failure.
    public static let maxSegments = 4

    /// Returns the ayah whole if it fits, otherwise the fewest waqf-bounded pieces that all do.
    ///
    /// - Parameter fits: whether a given string renders inside the icon's Arabic zone.
    public static func segments(of arabic: String, fitting fits: (String) -> Bool) -> [String] {
        if fits(arabic) { return [arabic] }

        let boundaries = waqfBoundaries(in: arabic)
        // No printed pause to break at — show it whole and let it truncate rather than
        // inventing one.
        guard !boundaries.isEmpty else { return [arabic] }

        for count in 2...min(boundaries.count + 1, maxSegments) {
            let pieces = split(arabic, at: boundaries, into: count)
            if pieces.count == count, pieces.allSatisfy(fits) { return pieces }
        }
        // Nothing fits even at the finest permitted division. Use it anyway — every piece still
        // ends on a real pause, which is the property that matters.
        return split(arabic, at: boundaries, into: min(boundaries.count + 1, maxSegments))
    }

    /// Indices just past each waqf mark, so a segment keeps the mark that ends it.
    private static func waqfBoundaries(in text: String) -> [String.Index] {
        var result: [String.Index] = []
        for index in text.indices where waqfMarks.contains(text[index]) {
            let after = text.index(after: index)
            // Ignore a mark that sits at the very end; it divides nothing.
            if after < text.endIndex { result.append(after) }
        }
        return result
    }

    /// Divides at the boundaries closest to even character counts, so no piece is far longer
    /// than the rest — the composer sizes every segment to the same zone.
    private static func split(
        _ text: String,
        at boundaries: [String.Index],
        into count: Int
    ) -> [String] {
        guard count > 1, !boundaries.isEmpty else { return [text] }
        let total = text.count
        var chosen: [String.Index] = []

        for piece in 1..<count {
            let target = total * piece / count
            let best = boundaries.min { lhs, rhs in
                let l = abs(text.distance(from: text.startIndex, to: lhs) - target)
                let r = abs(text.distance(from: text.startIndex, to: rhs) - target)
                return l < r
            }
            if let best, !chosen.contains(best) { chosen.append(best) }
        }
        chosen.sort()
        guard !chosen.isEmpty else { return [text] }

        var pieces: [String] = []
        var start = text.startIndex
        for boundary in chosen {
            let piece = text[start..<boundary].trimmingCharacters(in: .whitespaces)
            if !piece.isEmpty { pieces.append(piece) }
            start = boundary
        }
        let tail = text[start...].trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { pieces.append(tail) }
        return pieces.isEmpty ? [text] : pieces
    }
}
