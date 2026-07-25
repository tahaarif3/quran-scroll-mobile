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
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(IQColor.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        LaurelBadge(title: "#1 Muslim Focus App", subtitle: "Rated by early testers")
                            .frame(maxWidth: .infinity)

                        HighlightedText(
                            "Unlock focus.\n**Funded by the ummah.**",
                            style: .h1,
                            alignment: .center
                        )

                        Text("10% of every subscription becomes sadaqah jariyah.")
                            .iqraStyle(.body, color: IQColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        planRow(
                            plan: .annual,
                            title: "Annual",
                            price: purchases.annualPriceLabel,
                            detail: "\(purchases.annualMonthlyDerived) /mo",
                            badge: "SAVE \(purchases.savingsPercent)%"
                        )
                        planRow(
                            plan: .weekly,
                            title: "Weekly",
                            price: purchases.weeklyPriceLabel,
                            detail: "Billed weekly",
                            badge: nil
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            benefit("Shield distracting apps until you read")
                            benefit("Streaks, stats, and reminders")
                            benefit("Extra translations & transliteration")
                            benefit("Emergency passes & reader themes")
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, IQSpace.gutter)
                    .padding(.bottom, 120)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                ChunkyButton(
                    selectedPlan == .annual ? "Start 3-day free trial" : "Continue with weekly",
                    kind: .primary,
                    action: onPurchase
                )
                Button("Restore purchases", action: onRestore)
                    .iqraStyle(.captionStrong, color: IQColor.olive)
                Text("Cancel anytime in Settings. Reader stays free.")
                    .iqraStyle(.caption, color: IQColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, IQSpace.gutterWide)
            .padding(.bottom, IQSpace.ctaBottom)
            .padding(.top, 8)
            .background(IQColor.bgSand)
        }
    }

    private func planRow(plan: PaywallPlan, title: String, price: String, detail: String, badge: String?) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).iqraStyle(.bodyStrong)
                        if let badge {
                            Text(badge)
                                .iqraStyle(.captionStrong, color: IQColor.textOnGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(IQColor.goldBright))
                        }
                    }
                    Text(detail).iqraStyle(.caption, color: IQColor.textSecondary)
                }
                Spacer()
                Text(price).iqraStyle(.bodyStrong, color: IQColor.olive)
                ZStack {
                    Circle()
                        .strokeBorder(selectedPlan == plan ? IQColor.olive : IQColor.ringEmpty, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selectedPlan == plan {
                        Circle().fill(IQColor.olive).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .fill(selectedPlan == plan ? IQColor.oliveTint : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .strokeBorder(selectedPlan == plan ? IQColor.olive : IQColor.borderSubtle, lineWidth: selectedPlan == plan ? 2 : 1.6)
            )
        }
        .buttonStyle(.plain)
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(IQColor.olive)
            Text(text).iqraStyle(.body, color: IQColor.textPrimary)
        }
    }
}
