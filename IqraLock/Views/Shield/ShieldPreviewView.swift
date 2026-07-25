import SwiftUI
import IqraLockKit

/// In-app pixel-faithful screen 3d (OS shield is an approximation — see ShieldConfigurationExtension).
struct ShieldPreviewView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            IQColor.lockRadial.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(IQColor.appIconGradient)
                        .frame(width: 96, height: 96)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(IQColor.goldBright)
                }

                Text("Apps are locked")
                    .iqraStyle(.h1, color: IQColor.textOnDark)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Text(appModel.store.shieldSubtitle())
                        .iqraStyle(.bodyStrong, color: IQColor.gold)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(IQColor.goldBright)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .padding(.horizontal, 28)

                HStack(spacing: 16) {
                    LockedAppTile(label: "App", systemImage: "app.fill")
                    LockedAppTile(label: "App", systemImage: "app.fill")
                    LockedAppTile(label: "App", systemImage: "app.fill")
                    LockedAppTile(label: "App", systemImage: "app.fill")
                }

                Spacer()

                VStack(spacing: 12) {
                    ChunkyButton("Read now to unlock", kind: .gold) {
                        dismiss()
                        appModel.showReader = true
                    }
                    Button("Use emergency pass (\(appModel.store.emergencyPassesRemaining) left)") {
                        _ = appModel.screenTime.consumeEmergencyPass(durationMinutes: 15)
                        dismiss()
                    }
                    .iqraStyle(.captionStrong, color: IQColor.textOnDark.opacity(0.85))
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
