import Foundation
import SwiftData

/// Calendar-day-safe persistence for prayer logs. All callers fetch broadly and compare with
/// Calendar so store precision and timezone normalization cannot create duplicate "today" rows.
public enum PrayerLogStore {
    public static func completed(
        on day: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Set<String> {
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        return Set(
            logs
                .filter { calendar.isDate($0.day, inSameDayAs: day) }
                .flatMap(\.completed)
        )
    }

    public static func log(
        on day: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> PrayerLog? {
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        return logs.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

    @discardableResult
    public static func ensureLog(
        on day: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> PrayerLog {
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        let matches = logs.filter { calendar.isDate($0.day, inSameDayAs: day) }

        if let primary = matches.max(by: { $0.completed.count < $1.completed.count }) {
            let merged = Set(matches.flatMap(\.completed))
            primary.day = calendar.startOfDay(for: day)
            primary.completed = Array(merged)
            for duplicate in matches where duplicate.persistentModelID != primary.persistentModelID {
                context.delete(duplicate)
            }
            return primary
        }

        let created = PrayerLog(day: calendar.startOfDay(for: day))
        context.insert(created)
        return created
    }

    @discardableResult
    public static func setCompleted(
        _ completed: Set<String>,
        on day: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> PrayerLog {
        let log = try ensureLog(on: day, context: context, calendar: calendar)
        log.completed = Array(completed)
        try context.save()
        return log
    }

    @discardableResult
    public static func toggle(
        _ prayer: PrayerName,
        on day: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> PrayerLog {
        let log = try ensureLog(on: day, context: context, calendar: calendar)
        var completed = Set(log.completed)
        if !completed.insert(prayer.rawValue).inserted {
            completed.remove(prayer.rawValue)
        }
        log.completed = Array(completed)
        try context.save()
        return log
    }
}
