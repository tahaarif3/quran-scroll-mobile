import SwiftUI

public struct OnboardingScaffold<Content: View>: View {
    /// Only Welcome carries the gold radial. Every question, reveal and permission screen is
    /// flat sand — painting the radial behind all 17 steps was the single biggest visual drift
    /// from the design.
    public enum Backdrop: Equatable, Sendable {
        case sand
        case welcomeRadial
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let progress: Double?
    let backdrop: Backdrop
    let showsBack: Bool
    let onBack: (() -> Void)?
    let ctaTitle: String
    let ctaEnabled: Bool
    let ctaKind: ChunkyButtonStyle.Kind
    let centersContent: Bool
    let onCTA: () -> Void
    let content: Content

    public init(
        progress: Double? = nil,
        backdrop: Backdrop = .sand,
        showsBack: Bool = true,
        onBack: (() -> Void)? = nil,
        ctaTitle: String,
        ctaEnabled: Bool = true,
        ctaKind: ChunkyButtonStyle.Kind = .primary,
        centersContent: Bool = false,
        onCTA: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.backdrop = backdrop
        self.showsBack = showsBack
        self.onBack = onBack
        self.ctaTitle = ctaTitle
        self.ctaEnabled = ctaEnabled
        self.ctaKind = ctaKind
        self.centersContent = centersContent
        self.onCTA = onCTA
        self.content = content()
    }

    public var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
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
            ChunkyButton(ctaTitle, kind: ctaKind, enabled: ctaEnabled, action: onCTA)
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

    @ViewBuilder
    private var topBar: some View {
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

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(IQColor.track)
                        Capsule()
                            .fill(IQColor.accentOlive)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 7)
                // Deliberately lags the step transition so the advance is visible after the new
                // question lands, rather than moving under cover of the page change.
                //
                // NOTE: this only animates once the top bar outlives a step change. Today each
                // step builds its own OnboardingScaffold, so the bar is a *new* view every step
                // and SwiftUI has no previous width to interpolate from — the fill snaps. Making
                // the lag visible means hoisting the bar above the per-step content so a single
                // instance persists across the flow. Kept here so the behaviour lands with that
                // change rather than being rediscovered later.
                .animation(
                    reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.45).delay(0.1),
                    value: progress
                )
                .accessibilityLabel("Progress")
                .accessibilityValue("\(Int((progress * 100).rounded())) percent")
            } else {
                Spacer()
            }

            Color.clear.frame(width: 44, height: 44)
        }
        .frame(height: IQSpace.topBarHeight)
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
}
