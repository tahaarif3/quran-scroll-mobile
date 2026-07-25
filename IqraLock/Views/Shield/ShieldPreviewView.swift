import SwiftUI
import IqraLockKit

/// In-app screen 3d — pixel-faithful lock UI.
/// OS ManagedSettings shield uses ShieldConfigurationExtension approximation.
struct ShieldPreviewView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    var lockedAppName: String = "Instagram"

    var body: some View {
        ZStack {
            IQColor.lockRadial.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(IQColor.lockCTA)
                }

                VStack(spacing: 10) {
                    Text("\(lockedAppName) is locked")
                        .font(.custom("Nunito-Black", size: 28))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Finish today's Qur'an reading to unlock your distracting apps for the day.")
                        .iqraStyle(.body, color: Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("\(appModel.store.pagesReadToday) of \(appModel.store.dailyGoalPages) pages read")
                            .font(.custom("Nunito-Bold", size: 15))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(appModel.store.pagesRemaining) to go")
                            .font(.custom("Nunito-Bold", size: 15))
                            .foregroundStyle(IQColor.lockCTA)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(IQColor.lockCTA)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .padding(.horizontal, 28)

                HStack(spacing: 14) {
                    ForEach(LockedAppTile.Brand.allCases, id: \.self) { brand in
                        LockedAppTile(brand: brand, showLabel: false)
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    ChunkyButton("Read now to unlock →", kind: .gold) {
                        dismiss()
                        appModel.showReader = true
                    }
                    Button("Use emergency pass (\(appModel.store.emergencyPassesRemaining) left)") {
                        _ = appModel.screenTime.consumeEmergencyPass(durationMinutes: 15)
                        dismiss()
                    }
                    .iqraStyle(.caption, color: Color.white.opacity(0.55))
                }
                .padding(.horizontal, IQSpace.gutterWide)
                .padding(.bottom, IQSpace.ctaBottom)
            }
        }
    }

    private var progress: Double {
        let goal = max(1, appModel.store.dailyGoalPages)
        return min(1, Double(appModel.store.pagesReadToday) / Double(goal))
    }
}
