import SwiftUI
import SwiftData
import IqraLockKit

struct PrayerTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \PrayerLog.day, order: .reverse) private var logs: [PrayerLog]

    @State private var times: PrayerTimes?
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let times {
                if let next = times.nextPrayer() {
                    Text("Next: \(next.0.displayName) at \(next.1, format: .dateTime.hour().minute())")
                        .iqraStyle(.captionStrong, color: IQColor.accentOlive)
                }
                ForEach(PrayerName.allCases) { prayer in
                    prayerRow(prayer, time: times.time(for: prayer))
                }
            } else {
                Text("Set your location in You → Prayer times to see salah times.")
                    .iqraStyle(.body, color: IQColor.textMuted)
            }
        }
        .onAppear { refreshTimes() }
    }

    private func prayerRow(_ prayer: PrayerName, time: Date) -> some View {
        let done = isLogged(prayer)
        return Button {
            toggle(prayer)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? IQColor.accentOlive : IQColor.track)
                        .frame(width: 28, height: 28)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.displayName)
                        .iqraStyle(.bodyStrong, color: IQColor.textInk)
                    Text(time, format: .dateTime.hour().minute())
                        .iqraStyle(.caption, color: IQColor.textMuted)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func refreshTimes() {
        guard let profile, profile.prayerLatitude != 0 || profile.prayerLongitude != 0 else {
            times = nil
            return
        }
        times = PrayerTimesCalculator.compute(
            latitude: profile.prayerLatitude,
            longitude: profile.prayerLongitude
        )
    }

    private func todayLog() -> PrayerLog {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = logs.first(where: { Calendar.current.isDate($0.day, inSameDayAs: today) }) {
            return existing
        }
        let log = PrayerLog(day: today)
        modelContext.insert(log)
        return log
    }

    private func isLogged(_ prayer: PrayerName) -> Bool {
        todayLog().completed.contains(prayer.rawValue)
    }

    private func toggle(_ prayer: PrayerName) {
        let log = todayLog()
        if log.completed.contains(prayer.rawValue) {
            log.completed.removeAll { $0 == prayer.rawValue }
        } else {
            log.completed.append(prayer.rawValue)
        }
        try? modelContext.save()
    }
}
