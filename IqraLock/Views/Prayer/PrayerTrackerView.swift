import SwiftUI
import SwiftData
import IqraLockKit

struct PrayerTrackerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \PrayerLog.day, order: .reverse) private var logs: [PrayerLog]

    @State private var lastLoggedPrayer: PrayerName?
    @State private var showLoggedToast = false

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

    private var todayLog: PrayerLog? {
        let today = Calendar.current.startOfDay(for: Date())
        return logs.first { Calendar.current.isDate($0.day, inSameDayAs: today) }
    }

    private var completedToday: Set<String> {
        Set(todayLog?.completed ?? [])
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

    private func ensureTodayLog() -> PrayerLog {
        if let existing = todayLog { return existing }

        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.day == today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let log = PrayerLog(day: today)
        modelContext.insert(log)
        try? modelContext.save()
        return log
    }

    private func toggle(_ prayer: PrayerName) {
        let log = ensureTodayLog()
        var completed = log.completed
        let wasLogged = completed.contains(prayer.rawValue)

        if wasLogged {
            completed.removeAll { $0 == prayer.rawValue }
        } else {
            completed.append(prayer.rawValue)
        }
        log.completed = completed

        do {
            try modelContext.save()
            appModel.syncDailyProgress(context: modelContext)
        } catch {
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

    private func offsetLabel(for prayer: PrayerName) -> String {
        let offset = adjustments.offset(for: prayer)
        if offset == 0 { return "calculated" }
        let sign = offset > 0 ? "+" : ""
        return "\(sign)\(offset) min"
    }
}
