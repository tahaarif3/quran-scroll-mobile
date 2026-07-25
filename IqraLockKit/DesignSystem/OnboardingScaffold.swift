import SwiftUI

public struct OnboardingScaffold<Content: View>: View {
    let progress: Double?
    let showsBack: Bool
    let onBack: (() -> Void)?
    let ctaTitle: String
    let ctaEnabled: Bool
    let ctaKind: ChunkyButtonStyle.Kind
    let onCTA: () -> Void
    let content: Content

    public init(
        progress: Double? = nil,
        showsBack: Bool = true,
        onBack: (() -> Void)? = nil,
        ctaTitle: String,
        ctaEnabled: Bool = true,
        ctaKind: ChunkyButtonStyle.Kind = .primary,
        onCTA: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.showsBack = showsBack
        self.onBack = onBack
        self.ctaTitle = ctaTitle
        self.ctaEnabled = ctaEnabled
        self.ctaKind = ctaKind
        self.onCTA = onCTA
        self.content = content()
    }

    public var body: some View {
        ZStack {
            IQColor.welcomeRadial.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    content
                        .padding(.horizontal, IQSpace.gutter)
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChunkyButton(ctaTitle, kind: ctaKind, enabled: ctaEnabled, action: onCTA)
                .padding(.horizontal, IQSpace.gutterWide)
                .padding(.bottom, IQSpace.ctaBottom)
                .padding(.top, 12)
                .background(
                    LinearGradient(
                        colors: [IQColor.bgSand.opacity(0), IQColor.bgSand],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .offset(y: -28)
                    , alignment: .top
                )
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 12) {
            if showsBack {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(IQColor.textPrimary)
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
                        Capsule().fill(IQColor.chartNeutral)
                        Capsule()
                            .fill(IQColor.olive)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 6)
                .accessibilityLabel("Progress")
                .accessibilityValue("\(Int((progress * 100).rounded())) percent")
            } else {
                Spacer()
            }

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}
