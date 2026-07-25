import SwiftUI

// MARK: - Laurel Badge

public struct LaurelBadge: View {
    let title: String
    let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: 10) {
            laurel(flipped: true)
            VStack(spacing: 2) {
                Text(title)
                    .iqraStyle(.captionStrong, color: IQColor.olive)
                Text(subtitle)
                    .iqraStyle(.caption, color: IQColor.textSecondary)
            }
            laurel(flipped: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func laurel(flipped: Bool) -> some View {
        Image(systemName: "laurel.leading")
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(IQColor.gold)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
            .accessibilityHidden(true)
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(IQColor.goldBright)
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
        track: Color = Color.white.opacity(0.15),
        fill: Color = IQColor.gold
    ) {
        self.progress = min(1, max(0, progress))
        self.lineWidth = lineWidth
        self.size = size
        self.track = track
        self.fill = fill
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
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
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous)
                    .fill(IQColor.bgCard)
                    .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
            )
    }
}

// MARK: - Locked App Tile

public struct LockedAppTile: View {
    let label: String
    let systemImage: String
    let dimmed: Bool

    public init(label: String, systemImage: String = "app.fill", dimmed: Bool = true) {
        self.label = label
        self.systemImage = systemImage
        self.dimmed = dimmed
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: 0xD9CDB8))
                    .frame(width: 56, height: 56)
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(IQColor.textSecondary)
                if dimmed {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(label)
                .iqraStyle(.caption, color: IQColor.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .accessibilityLabel("\(label), locked")
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
            Text("🔥")
            Text("\(days) day streak")
                .iqraStyle(.captionStrong, color: IQColor.olive)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(IQColor.oliveTint))
        .overlay(Capsule().strokeBorder(IQColor.olive.opacity(0.25), lineWidth: 1))
        .accessibilityLabel("\(days) day streak")
    }
}
