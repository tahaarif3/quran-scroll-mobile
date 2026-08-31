import Foundation
import SwiftData

/// Bridges live App Group counters into SwiftData so streak, progress and khatm pace stay honest.
///
/// Today's reading lives in `AppGroupStore` for extensions; historical stats live in `DailyRecord`.
/// Without syncing, Home's streak pill and the Progress tab always read zero.
public enum DailyProgressSync {
    /// Upserts today's record from the current App Group state.
    public static func upsertToday(
        context: ModelContext,
        store: AppGroupStore,
        minutesDelta: Int = 0,
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.day == day }
        )
        let existing = (try? context.fetch(descriptor))?.first
        let record = existing ?? {
            let r = DailyRecord(
                day: day,
                goalPages: store.dailyGoalPages
            )
            context.insert(r)
            return r
        }()
        record.pagesRead = store.pagesReadToday
        record.goalMet = store.goalMetToday
        record.goalPages = store.dailyGoalPages
        if minutesDelta > 0 {
            record.minutesRead += minutesDelta
        } else if record.minutesRead == 0, store.totalAyahsToday > 0 {
            // Estimate from ayahs read when no session timer exists yet.
            record.minutesRead = store.totalAyahsToday * max(1, store.ayahUnlockMinutes / 3)
        }
        try? context.save()
    }

    /// When the calendar day rolls, persist yesterday before counters reset.
    public static func finalizeDayIfRolling(
        context: ModelContext,
        store: AppGroupStore,
        previousDayKey: String,
        calendar: Calendar = .current
    ) {
        guard !previousDayKey.isEmpty, previousDayKey != store.dayKey else { return }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let previousDate = formatter.date(from: previousDayKey) else { return }
        let day = calendar.startOfDay(for: previousDate)
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.day == day }
        )
        _ = (try? context.fetch(descriptor))?.first ?? {
            let r = DailyRecord(day: day, goalPages: store.dailyGoalPages)
            context.insert(r)
            return r
        }()
        // Values may already be zero after roll — this path is for explicit finalize calls.
        try? context.save()
    }

    /// Merges today's live App Group state into records before computing stats.
    public static func recordsIncludingToday(
        stored: [DailyRecord],
        store: AppGroupStore,
        calendar: Calendar = .current
    ) -> [HabitStatsCalculator.DayInput] {
        let today = calendar.startOfDay(for: Date())
        var inputs = stored.map {
            HabitStatsCalculator.DayInput(
                day: $0.day,
                pagesRead: $0.pagesRead,
                minutesRead: $0.minutesRead,
                goalMet: $0.goalMet
            )
        }
        if let index = inputs.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: today) }) {
            inputs[index] = HabitStatsCalculator.DayInput(
                day: today,
                pagesRead: store.pagesReadToday,
                minutesRead: max(inputs[index].minutesRead, estimatedMinutes(store: store)),
                goalMet: store.goalMetToday
            )
        } else if store.totalAyahsToday > 0 || store.pagesReadToday > 0 {
            inputs.append(HabitStatsCalculator.DayInput(
                day: today,
                pagesRead: store.pagesReadToday,
                minutesRead: estimatedMinutes(store: store),
                goalMet: store.goalMetToday
            ))
        }
        return inputs
    }

    public static func estimatedMinutes(store: AppGroupStore) -> Int {
        max(1, store.totalAyahsToday) * max(1, store.ayahUnlockMinutes / 3)
    }

    public static func weekdayLabels(
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        // weekCompletion[0] = 6 days ago … [6] = today
        return (0..<7).map { offset in
            let daysAgo = 6 - offset
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: date)) else {
                return "?"
            }
            let weekday = calendar.component(.weekday, from: day)
            return symbols[weekday - 1]
        }
    }
}
