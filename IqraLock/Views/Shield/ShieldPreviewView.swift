import SwiftUI
import IqraLockKit

/// In-app preview of the OS shield — ayah-first, matching the live lock screen.
struct ShieldPreviewView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    var lockedAppName: String = "Instagram"

    @State private var segment: ShieldAyahProvider.Segmented?
    @State private var showBathroomConfirm = false

    private var store: AppGroupStore { appModel.store }

    var body: some View {
        ZStack {
            IQColor.lockRadial.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 72, height: 72)
                    IQIconView(.lock, size: 32)
                }

                if let segment {
                    Text(segment.arabic)
                        .font(.custom("Amiri-Bold", size: 26))
                        .foregroundStyle(IQColor.lockCTA)
                        .multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding(.horizontal, 20)

                    Text(segment.subtitle)
                        .iqraStyle(.body, color: Color.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("\(lockedAppName) is locked")
                        .font(.custom("Nunito-Black", size: 26))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                progressCard
                    .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {
                    ChunkyButton(
                        "Open \(lockedAppName) · \(store.ayahUnlockMinutes) min",
                        kind: .gold
                    ) {
                        dismiss()
                        appModel.showReader = true
                    }
                    Button(segment?.secondaryLabel ?? "Read another ayah") {
                        dismiss()
                        appModel.showReader = true
                    }
                    .iqraStyle(.captionStrong, color: IQColor.lockCTA)
                    .frame(maxWidth: .infinity, minHeight: 44)

                    Button("Bathroom break · 5 min (\(store.bathroomBreaksRemaining) left)") {
                        showBathroomConfirm = true
                    }
                    .iqraStyle(.caption, color: Color.white.opacity(0.5))
                }
                .padding(.horizontal, IQSpace.gutterWide)
                .padding(.bottom, IQSpace.ctaBottom)
            }
        }
        .onAppear { loadSegment() }
        .confirmationDialog(
            "Use a bathroom break?",
            isPresented: $showBathroomConfirm,
            titleVisibility: .visible
        ) {
            Button("Open apps for 5 minutes") {
                _ = appModel.screenTime.consumeBathroomBreak(durationMinutes: 5)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your apps open for 5 minutes. \(store.bathroomBreaksRemaining) left this month.")
        }
    }

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(store.totalAyahsToday) of \(store.dailyGoalAyahs) ayahs")
                    .font(.custom("Nunito-Bold", size: 15))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(max(0, store.dailyGoalAyahs - store.totalAyahsToday)) to go")
                    .font(.custom("Nunito-Bold", size: 15))
                    .foregroundStyle(IQColor.lockCTA)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(IQColor.lockCTA)
                        .frame(width: geo.size.width * ayahProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private var ayahProgress: Double {
        let goal = max(1, store.dailyGoalAyahs)
        return min(1, Double(store.totalAyahsToday) / Double(goal))
    }

    private func loadSegment() {
        segment = ShieldAyahProvider.segmented(for: store)
    }
}
