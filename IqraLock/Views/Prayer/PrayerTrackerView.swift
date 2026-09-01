import SwiftUI
import SwiftData
import IqraLockKit

struct PrayerTrackerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \PrayerLog.day, order: .reverse) private var logs: [PrayerLog]

    private var profile: UserProfile? { profiles.first }

    private var times: PrayerTimes? {
        _ = appModel.prayerCityVersion
        guard let coords = PrayerCitySelection.coordinates(profile: profile, store: appModel.store) else {
            return nil
        }
        return PrayerTimesCalculator.compute(
            latitude: coords.latitude,
            longitude: coords.longitude
        )
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
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
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
                        Text(time, format: .dateTime.hour().minute())
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
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous))
        .accessibilityLabel("\(prayer.displayName), \(done ? "logged" : "not logged")")
        .accessibilityHint("Double tap to \(done ? "remove" : "log") this prayer")
    }

    private func ensureTodayLog() -> PrayerLog {
        if let existing = todayLog { return existing }
        let log = PrayerLog(day: Date())
        modelContext.insert(log)
        return log
    }

    private func toggle(_ prayer: PrayerName) {
        let log = ensureTodayLog()
        if log.completed.contains(prayer.rawValue) {
            log.completed.removeAll { $0 == prayer.rawValue }
        } else {
            log.completed.append(prayer.rawValue)
        }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
