import SwiftUI

// MARK: - App Icon (اقرأ + crescent)

public struct IqraAppIcon: View {
    let size: CGFloat

    public init(size: CGFloat = 108) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(IQColor.appIconGradient)
                .shadow(
                    color: IQShadow.appIcon.color,
                    radius: IQShadow.appIcon.radius,
                    y: IQShadow.appIcon.y
                )
            VStack(spacing: size * 0.02) {
                CrescentShape()
                    .fill(IQColor.iconCrescent)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .offset(y: size * 0.04)
                Text("اقرأ")
                    .font(.custom("Amiri-Bold", size: size * 0.34))
                    .foregroundStyle(IQColor.iconGlyph)
                    .offset(y: -size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("IqraLock")
    }
}

public struct CrescentShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(center: c, radius: r, startAngle: .degrees(-40), endAngle: .degrees(220), clockwise: false)
        path.addArc(
            center: CGPoint(x: c.x + r * 0.28, y: c.y - r * 0.08),
            radius: r * 0.78,
            startAngle: .degrees(200),
            endAngle: .degrees(-20),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Laurel Mark

/// A filled 34×52 mark. Drawn at 28pt regular it rendered as a hairline glyph roughly half the
/// size the design calls for, which is why the social-proof badge read as thin in the build.
public struct LaurelMark: View {
    public enum Side: Sendable {
        case leading
        case trailing
    }

    let side: Side
    let color: Color

    public init(_ side: Side, color: Color = IQColor.brandPrimary) {
        self.side = side
        self.color = color
    }

    public var body: some View {
        Image(systemName: side == .leading ? "laurel.leading" : "laurel.trailing")
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 52)
            .accessibilityHidden(true)
    }
}

// MARK: - Laurel Badge

public struct LaurelBadge: View {
    let title: String
    let showStars: Bool

    public init(title: String = "#1 Muslim Focus App", showStars: Bool = true) {
        self.title = title
        self.showStars = showStars
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                LaurelMark(.leading)
                Text(title)
                    .iqraStyle(.captionStrong, color: IQColor.brandPrimary)
                LaurelMark(.trailing)
            }
            if showStars {
                StarRating(rating: 5)
            }
        }
    }
}

// MARK: - Star Rating

public struct StarRating: View {
    let rating: Double
    let maxStars: Int

    public init(rating: Double = 5, maxStars: Int = 5) {
        self.rating = rating
        self.maxStars = maxStars
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxStars, id: \.self) { index in
                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(IQColor.star)
            }
        }
        .accessibilityLabel("\(rating, specifier: "%.1f") out of \(maxStars) stars")
    }
}

// MARK: - Progress Ring

public struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let track: Color
    let fill: Color

    public init(
        progress: Double,
        lineWidth: CGFloat = 10,
        size: CGFloat = 120,
        track: Color = Color.white.opacity(0.12),
        fill: Color = IQColor.accentGoldOnDark
    ) {
        self.progress = min(1, max(0, progress))
        self.lineWidth = lineWidth
        self.size = size
        self.track = track
        self.fill = fill
    }

    public var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Reading progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

// MARK: - Section Card

public struct SectionCard<Content: View>: View {
    let elevated: Bool
    let content: Content

    public init(elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                    .fill(IQColor.bgCard)
                    .shadow(
                        color: (elevated ? IQShadow.elevated : IQShadow.card).color,
                        radius: (elevated ? IQShadow.elevated : IQShadow.card).radius,
                        y: (elevated ? IQShadow.elevated : IQShadow.card).y
                    )
            )
    }
}

// MARK: - Locked App Tile

public struct LockedAppTile: View {
    public enum Brand: String, CaseIterable {
        case instagram, facebook, tiktok, linkedin

        public var label: String {
            switch self {
            case .instagram: return "Instagram"
            case .facebook: return "Facebook"
            case .tiktok: return "TikTok"
            case .linkedin: return "LinkedIn"
            }
        }

        public var color: Color {
            switch self {
            case .instagram: return Color(hex: 0xE1306C)
            case .facebook: return Color(hex: 0x1877F2)
            case .tiktok: return Color(hex: 0x111111)
            case .linkedin: return Color(hex: 0x0A66C2)
            }
        }

        public var glyph: String {
            switch self {
            case .instagram: return "camera.fill"
            case .facebook: return "f.square.fill"
            case .tiktok: return "music.note"
            case .linkedin: return "briefcase.fill"
            }
        }
    }

    let brand: Brand
    let dimmed: Bool
    let showLabel: Bool

    public init(brand: Brand, dimmed: Bool = true, showLabel: Bool = true) {
        self.brand = brand
        self.dimmed = dimmed
        self.showLabel = showLabel
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(brand.color)
                    .frame(width: 56, height: 56)
                Image(systemName: brand.glyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                if dimmed {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 56, height: 56)
                    IQIconView(.lock, size: 20)
                }
            }
            if showLabel {
                Text(brand.label)
                    .iqraStyle(.finePrint, color: IQColor.textMuted)
                    .lineLimit(1)
            }
        }
        .frame(width: 72)
        .accessibilityLabel("\(brand.label), locked")
    }
}

// MARK: - Streak Pill

public struct StreakPill: View {
    let days: Int

    public init(days: Int) {
        self.days = days
    }

    public var body: some View {
        HStack(spacing: 6) {
            IQIconView(.flame, size: 18)
            Text("\(days)")
                .font(.custom("Nunito-ExtraBold", size: 16))
                .foregroundStyle(IQColor.brandGold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.white)
                .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
        )
        .accessibilityLabel("\(days) day streak")
    }
}

// MARK: - Highlighted Text (re-export convenience already in HighlightedText.swift)
