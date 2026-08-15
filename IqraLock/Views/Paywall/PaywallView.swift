import SwiftUI
import IqraLockKit

struct PaywallView: View {
    /// Seconds the paywall must be shown before the skip control becomes available.
    static let skipDelay: Duration = .seconds(3)

    let purchases: PurchaseService
    @Binding var selectedPlan: PaywallPlan
    var onSkip: () -> Void
    var onPurchase: () -> Void
    var onRestore: () -> Void
    /// Fired when the skip control becomes available, so the funnel can separate
    /// "never saw a way out" from "saw it and chose to subscribe".
    var onSkipRevealed: (() -> Void)?

    @State private var canSkip = false

    var body: some View {
        ZStack {
            // Flat sand, matching 2r in the design. The radial belongs to Welcome only.
            IQColor.bgSand.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if canSkip {
                        Button(action: onSkip) {
                            Text("Skip")
                                .iqraStyle(.captionStrong, color: IQColor.textMuted2)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Skip and continue with the free version")
                        .transition(.opacity)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 12)
                .animation(.easeOut(duration: 0.2), value: canSkip)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(spacing: 6) {
                            IQIconView(.dua, size: 18)
                            Text("Funded by the ummah")
                                .iqraStyle(.captionStrong, color: IQColor.accentOlive)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(IQColor.oliveTint))

                        Text("Keep IqraLock ad-free — and give back")
                            .iqraStyle(.h1, color: IQColor.textInk)
                            .multilineTextAlignment(.center)

                        Text("No ads, no data selling — just members funding a mission that gives back.")
                            .iqraStyle(.subtitle, color: IQColor.textMuted)
                            .multilineTextAlignment(.center)

                        planRow(
                            plan: .annual,
                            title: "Yearly",
                            detail: "3-day free trial, then \(purchases.annualPriceLabel)/yr",
                            price: purchases.annualMonthlyDerived,
                            unit: "/mo",
                            badge: "SAVE \(purchases.savingsPercent)%"
                        )
                        planRow(
                            plan: .weekly,
                            title: "Weekly",
                            detail: "Billed weekly · cancel anytime",
                            price: purchases.weeklyPriceLabel,
                            unit: "/wk",
                            badge: nil
                        )

                        HStack(alignment: .top, spacing: 12) {
                            IQIconView(.globe, size: 30)
                            // One flowing sentence with the figure emphasised, as in the design —
                            // it was two stacked lines, which reads as a heading over a caption
                            // rather than a single claim.
                            HighlightedText(
                                "**10% of every subscription** becomes sadaqah jariyah — wells, mushafs & meals.",
                                style: .caption,
                                color: IQColor.textMuted2,
                                highlight: IQColor.textInk
                            )
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
                        )
                    }
                    .padding(.horizontal, IQSpace.gutter)
                    .padding(.bottom, 140)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                ChunkyButton(
                    selectedPlan == .annual ? "Start 3-day free trial →" : "Continue with weekly →",
                    kind: .primary,
                    action: onPurchase
                )
                HStack(spacing: 4) {
                    Text("Then \(purchases.annualPriceLabel)/year · cancel anytime ·")
                        .iqraStyle(.finePrint, color: IQColor.textFaint)
                    Button("Restore", action: onRestore)
                        .iqraStyle(.finePrint, color: IQColor.brandPrimary)
                }
            }
            .padding(.horizontal, IQSpace.gutterWide)
            .padding(.bottom, IQSpace.ctaBottom)
            .padding(.top, 8)
            .background(IQColor.bgSand)
        }
        // `.task` rather than `onAppear` + DispatchQueue: it is main-actor-bound, so the state
        // flip always lands on the live view, and it is cancelled automatically if the paywall
        // goes away before the delay elapses.
        .task {
            try? await Task.sleep(for: Self.skipDelay)
            guard !Task.isCancelled else { return }
            canSkip = true
            onSkipRevealed?()
        }
    }

    private func planRow(
        plan: PaywallPlan,
        title: String,
        detail: String,
        price: String,
        unit: String,
        badge: String?
    ) -> some View {
        Button { selectedPlan = plan } label: {
            HStack(spacing: 12) {
                ZStack {
                    if selectedPlan == plan {
                        Circle().fill(IQColor.accentOlive).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .strokeBorder(IQColor.radioEmpty, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).iqraStyle(.option, color: IQColor.textInk)
                        if let badge {
                            Text(badge)
                                .iqraStyle(.finePrint, color: IQColor.brandPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(IQColor.savePill))
                        }
                    }
                    Text(detail).iqraStyle(.caption, color: IQColor.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(price).iqraStyle(.h3, color: IQColor.textInk)
                    Text(unit).iqraStyle(.finePrint, color: IQColor.textMuted)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                    .fill(selectedPlan == plan ? IQColor.oliveTint : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                    .strokeBorder(
                        selectedPlan == plan ? IQColor.accentOlive : IQColor.borderSubtle,
                        lineWidth: selectedPlan == plan ? 2 : 1.6
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
