import SwiftUI
import SwiftData
import IqraLockKit

struct PrayerTrackerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var lastLoggedPrayer: PrayerName?
    @State private var showLoggedToast = false
    @State private var completedToday: Set<String> = []

    private var profile: UserProfile? { profiles.first }

    private var times: PrayerTimes? {
        _ = appModel.prayerScheduleVersion
        guard let coords = PrayerCitySelection.coordinates(profile: profile, store: appModel.store) else {
            return nil
        }
        let adjustments = PrayerTimeSettings.load(profile: profile, store: appModel.store)
        return PrayerTimesResolver.resolve(
            latitude: coords.latitude,
            longitude: coords.longitude,
            adjustments: adjustments
        )
    }

    private var adjustments: PrayerTimeAdjustments {
        PrayerTimeSettings.load(profile: profile, store: appModel.store)
    }

    private var completedCount: Int {
        PrayerName.allCases.filter { completedToday.contains($0.rawValue) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if times != nil || !PrayerName.allCases.isEmpty {
                header
                ForEach(PrayerName.allCases) { prayer in
                    prayerRow(
                        prayer,
                        time: times?.time(for: prayer)
                    )
                }
            } else {
                Text("Choose your city in You → Prayer & reminders to see salah times.")
                    .iqraStyle(.body, color: IQColor.textMuted)
            }
        }
        .overlay(alignment: .top) {
            if showLoggedToast, let lastLoggedPrayer {
                Text("\(lastLoggedPrayer.displayName) logged · streak updated")
                    .iqraStyle(.captionStrong, color: IQColor.textInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(IQColor.oliveTint)
                            .overlay(
                                Capsule().stroke(IQColor.accentOlive.opacity(0.35), lineWidth: 1)
                            )
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: completedToday)
        .onAppear { refreshCompletedToday() }
        .onChange(of: appModel.prayerLogVersion) { _, _ in refreshCompletedToday() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(completedCount) of \(PrayerName.allCases.count) prayed today")
                    .iqraStyle(.captionStrong, color: IQColor.textInk)
                Spacer()
                if completedCount == PrayerName.allCases.count {
                    Text("Alhamdulillah")
                        .iqraStyle(.captionStrong, color: IQColor.accentOlive)
                }
            }

            if completedCount > 0 {
                Text("Logged prayers count toward your streak.")
                    .iqraStyle(.caption, color: IQColor.accentOlive)
            }

            if let times, let next = times.nextPrayer() {
                Text("Next: \(next.0.displayName) at \(next.1, format: .dateTime.hour().minute())")
                    .iqraStyle(.caption, color: IQColor.textMuted)
            } else if times == nil {
                Text("Set your city in You for accurate salah times.")
                    .iqraStyle(.caption, color: IQColor.textMuted)
            }

            Text("Tap each prayer when you've prayed it.")
                .iqraStyle(.caption, color: IQColor.textFaint)
        }
    }

    private func prayerRow(_ prayer: PrayerName, time: Date?) -> some View {
        let done = completedToday.contains(prayer.rawValue)
        return Button {
            toggle(prayer)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? IQColor.accentOlive : IQColor.track)
                        .frame(width: 32, height: 32)
                        .scaleEffect(done ? 1.0 : 0.96)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(IQColor.textFaint)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.displayName)
                        .iqraStyle(.bodyStrong, color: IQColor.textInk)
                    if let time {
                        HStack(spacing: 4) {
                            Text(time, format: .dateTime.hour().minute())
                            if adjustments.isAdjusted(prayer) {
                                Text("(\(offsetLabel(for: prayer)))")
                            }
                        }
                        .iqraStyle(.caption, color: IQColor.textMuted)
                    } else {
                        Text("Tap to log")
                            .iqraStyle(.caption, color: IQColor.textMuted)
                    }
                }

                Spacer()

                Text(done ? "Logged" : "Log")
                    .iqraStyle(.captionStrong, color: done ? IQColor.accentOlive : IQColor.brandPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .fill(done ? IQColor.oliveTint : IQColor.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .stroke(done ? IQColor.accentOlive.opacity(0.35) : IQColor.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PrayerLogButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous))
        .accessibilityLabel("\(prayer.displayName), \(done ? "logged" : "not logged")")
        .accessibilityHint("Double tap to \(done ? "remove" : "log") this prayer")
    }

    private func toggle(_ prayer: PrayerName) {
        let previous = completedToday
        let wasLogged = previous.contains(prayer.rawValue)
        var updated = previous

        if wasLogged {
            updated.remove(prayer.rawValue)
        } else {
            updated.insert(prayer.rawValue)
        }
        // Update the controls immediately; SwiftData persistence follows below.
        completedToday = updated

        do {
            try PrayerLogStore.setCompleted(updated, context: modelContext)
            appModel.syncDailyProgress(context: modelContext)
            appModel.prayerLogVersion += 1
        } catch {
            completedToday = previous
            #if DEBUG
            print("Prayer log save failed: \(error)")
            #endif
            return
        }

        UIImpactFeedbackGenerator(style: wasLogged ? .soft : .medium).impactOccurred()
        if !wasLogged {
            lastLoggedPrayer = prayer
            showLoggedToast = true
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                showLoggedToast = false
            }
        }
    }

    private func refreshCompletedToday() {
        do {
            completedToday = try PrayerLogStore.completed(context: modelContext)
        } catch {
            #if DEBUG
            print("Prayer log reload failed: \(error)")
            #endif
        }
    }

    private func offsetLabel(for prayer: PrayerName) -> String {
        let offset = adjustments.offset(for: prayer)
        if offset == 0 { return "calculated" }
        let sign = offset > 0 ? "+" : ""
        return "\(sign)\(offset) min"
    }
}

private struct PrayerLogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
