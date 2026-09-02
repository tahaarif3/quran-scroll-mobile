import Foundation
import SwiftData

/// Connects prayer logging to streak / daily goal tracking.
public enum PrayerProgressSync {
    public static func hasPrayersLogged(
        on day: Date,
        logs: [PrayerLog],
        calendar: Calendar = .current
    ) -> Bool {
        let key = calendar.startOfDay(for: day)
        return logs.contains {
            calendar.startOfDay(for: $0.day) == key && !$0.completed.isEmpty
        }
    }

    public static func completedCount(
        on day: Date,
        logs: [PrayerLog],
        calendar: Calendar = .current
    ) -> Int {
        let key = calendar.startOfDay(for: day)
        guard let log = logs.first(where: { calendar.startOfDay(for: $0.day) == key }) else {
            return 0
        }
        return Set(log.completed).intersection(Set(PrayerName.allCases.map(\.rawValue))).count
    }

    /// A day counts toward the streak when the reading goal is met or at least one prayer is logged.
    public static func contributesToStreak(
        readingGoalMet: Bool,
        prayersLogged: Bool
    ) -> Bool {
        readingGoalMet || prayersLogged
    }

    public static func upsertToday(
        context: ModelContext,
        store: AppGroupStore,
        calendar: Calendar = .current
    ) {
        let logs = (try? context.fetch(FetchDescriptor<PrayerLog>())) ?? []
        let prayersLogged = hasPrayersLogged(on: Date(), logs: logs, calendar: calendar)
        DailyProgressSync.upsertToday(
            context: context,
            store: store,
            prayersContributeToGoal: prayersLogged,
            calendar: calendar
        )
    }
}
