import SwiftUI
import IqraLockKit

struct PaywallView: View {
    let purchases: PurchaseService
    @Binding var selectedPlan: PaywallPlan
    var onClose: () -> Void
    var onPurchase: () -> Void
    var onRestore: () -> Void

    var body: some View {
        ZStack {
            IQColor.welcomeRadial.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(IQColor.textFaint)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.horizontal, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Text("🤲 Funded by the ummah")
                            .iqraStyle(.captionStrong, color: IQColor.accentOlive)
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
                            Text("🌍").font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("10% of every subscription")
                                    .iqraStyle(.bodyStrong, color: IQColor.textInk)
                                Text("becomes sadaqah jariyah — wells, mushafs & meals.")
                                    .iqraStyle(.caption, color: IQColor.textMuted2)
                            }
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
