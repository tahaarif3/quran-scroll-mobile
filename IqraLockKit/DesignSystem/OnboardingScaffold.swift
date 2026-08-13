import SwiftUI

/// The onboarding header, deliberately kept *outside* `OnboardingScaffold`.
///
/// Each step builds its own scaffold, so a bar owned by the scaffold was a brand-new view on every
/// step — SwiftUI had no previous width to interpolate from and the fill snapped to each new value
/// no matter what animation was attached. The flow view draws one of these above the transitioning
/// content instead, so a single instance persists for the whole flow and the fill can travel.
public struct OnboardingTopBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Last non-nil progress. The bar fades out on steps that don't show a track (reveals,
    /// permission screens) but must not rewind to zero — otherwise returning to a question would
    /// animate the fill up from empty instead of resuming where it left off.
    @State private var displayedProgress: Double = 0

    let progress: Double?
    let showsBack: Bool
    let onBack: (() -> Void)?

    public init(progress: Double?, showsBack: Bool, onBack: (() -> Void)? = nil) {
        self.progress = progress
        self.showsBack = showsBack
        self.onBack = onBack
    }

    public var body: some View {
        HStack(spacing: 12) {
            if showsBack {
                Button { onBack?() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(IQColor.textFaint)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            track

            Color.clear.frame(width: 44, height: 44)
        }
        .frame(height: IQSpace.topBarHeight)
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(IQColor.track)
                Capsule()
                    .fill(IQColor.accentOlive)
                    .frame(width: max(8, geo.size.width * displayedProgress))
            }
        }
        .frame(height: 7)
        .opacity(progress == nil ? 0 : 1)
        // Lags the step transition on purpose: moving the fill at the same moment the new
        // question lands hides the advance, because the eye is on the incoming text.
        .animation(
            reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.45).delay(0.1),
            value: displayedProgress
        )
        .animation(.easeOut(duration: 0.2), value: progress == nil)
        .onChange(of: progress, initial: true) { _, new in
            if let new { displayedProgress = new }
        }
        .accessibilityHidden(progress == nil)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(((progress ?? 0) * 100).rounded())) percent")
    }
}

public struct OnboardingScaffold<Content: View>: View {
    /// Only Welcome carries the gold radial. Every question, reveal and permission screen is
    /// flat sand — painting the radial behind all 17 steps was the single biggest visual drift
    /// from the design.
    public enum Backdrop: Equatable, Sendable {
        case sand
        case welcomeRadial
    }

    let backdrop: Backdrop
    let ctaTitle: String
    let ctaEnabled: Bool
    let ctaKind: ChunkyButtonStyle.Kind
    let centersContent: Bool
    let skipTitle: String?
    let onSkip: (() -> Void)?
    let onCTA: () -> Void
    let content: Content

    public init(
        backdrop: Backdrop = .sand,
        ctaTitle: String,
        ctaEnabled: Bool = true,
        ctaKind: ChunkyButtonStyle.Kind = .primary,
        centersContent: Bool = false,
        skipTitle: String? = nil,
        onSkip: (() -> Void)? = nil,
        onCTA: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.backdrop = backdrop
        self.ctaTitle = ctaTitle
        self.ctaEnabled = ctaEnabled
        self.ctaKind = ctaKind
        self.centersContent = centersContent
        self.skipTitle = skipTitle
        self.onSkip = onSkip
        self.onCTA = onCTA
        self.content = content()
    }

    public var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            VStack(spacing: 0) {
                // Holds the space the persistent OnboardingTopBar occupies. Reserving it here
                // rather than letting the bar push content down keeps every step's content at the
                // same offset whether or not that step draws a progress track.
                Color.clear
                    .frame(height: IQSpace.topBarHeight)
                    .padding(.top, 2)

                if centersContent {
                    Spacer(minLength: 8)
                    content
                        .padding(.horizontal, IQSpace.gutter)
                    Spacer(minLength: 8)
                } else {
                    ScrollView(showsIndicators: false) {
                        content
                            .padding(.horizontal, IQSpace.gutter)
                            .padding(.top, 8)
                            .padding(.bottom, 130)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                ChunkyButton(ctaTitle, kind: ctaKind, enabled: ctaEnabled, action: onCTA)
                if let skipTitle, let onSkip {
                    Button(action: onSkip) {
                        Text(skipTitle)
                            .iqraStyle(.captionStrong, color: IQColor.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Skips this question. You can change it later in settings.")
                }
            }
            .padding(.horizontal, IQSpace.gutterWide)
            .padding(.bottom, IQSpace.ctaBottom)
            .padding(.top, 10)
            .background(IQColor.bgSand.opacity(0.92))
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch backdrop {
        case .sand:
            IQColor.bgSand
        case .welcomeRadial:
            GeometryReader { proxy in
                Rectangle().fill(IQColor.welcomeRadial(height: proxy.size.height))
            }
        }
    }
}
