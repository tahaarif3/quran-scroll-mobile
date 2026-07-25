import Foundation

public struct HabitStats: Equatable, Sendable {
    public var streakDays: Int
    public var weekCompletion: [Bool] // Sun...Sat or Mon...Sun — uses calendar weekday order starting Monday
    public var pagesReadTotal: Int
    public var surahsCompleted: Int
    public var minutesLast7Days: [Int]
    /// Product claim: sum(minutesRead) — time redirected from scroll to scripture.
    public var minutesReclaimed: Int

    public var hoursReclaimedLabel: String {
        let hours = Double(minutesReclaimed) / 60.0
        if hours < 10 {
            return String(format: "%.0fh", hours.rounded())
        }
        return "\(Int(hours.rounded()))h"
    }

    public init(
        streakDays: Int = 0,
        weekCompletion: [Bool] = Array(repeating: false, count: 7),
        pagesReadTotal: Int = 0,
        surahsCompleted: Int = 0,
        minutesLast7Days: [Int] = Array(repeating: 0, count: 7),
        minutesReclaimed: Int = 0
    ) {
        self.streakDays = streakDays
        self.weekCompletion = weekCompletion
        self.pagesReadTotal = pagesReadTotal
        self.surahsCompleted = surahsCompleted
        self.minutesLast7Days = minutesLast7Days
        self.minutesReclaimed = minutesReclaimed
    }
}

public enum HabitStatsCalculator {
    public struct DayInput: Equatable, Sendable {
        public var day: Date
        public var pagesRead: Int
        public var minutesRead: Int
        public var goalMet: Bool

        public init(day: Date, pagesRead: Int, minutesRead: Int, goalMet: Bool) {
            self.day = day
            self.pagesRead = pagesRead
            self.minutesRead = minutesRead
            self.goalMet = goalMet
        }
    }

    public static func compute(
        records: [DayInput],
        now: Date = Date(),
        calendar: Calendar = .current,
        surahsCompleted: Int = 0
    ) -> HabitStats {
        let startOfToday = calendar.startOfDay(for: now)
        let byDay: [Date: DayInput] = Dictionary(
            uniqueKeysWithValues: records.map { (calendar.startOfDay(for: $0.day), $0) }
        )

        // Streak: consecutive goal-met days ending today or yesterday.
        var streak = 0
        var cursor = startOfToday
        if byDay[cursor]?.goalMet != true {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
               byDay[yesterday]?.goalMet == true {
                cursor = yesterday
            } else {
                cursor = startOfToday
            }
        }
        while let rec = byDay[cursor], rec.goalMet {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        // Week completion — last 7 days ending today, index 0 = 6 days ago … 6 = today
        var week = Array(repeating: false, count: 7)
        var minutes = Array(repeating: 0, count: 7)
        for offset in 0..<7 {
            let daysAgo = 6 - offset
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) else { continue }
            let rec = byDay[calendar.startOfDay(for: day)]
            week[offset] = rec?.goalMet ?? false
            minutes[offset] = rec?.minutesRead ?? 0
        }

        let pagesTotal = records.reduce(0) { $0 + $1.pagesRead }
        let reclaimed = records.reduce(0) { $0 + $1.minutesRead }

        return HabitStats(
            streakDays: streak,
            weekCompletion: week,
            pagesReadTotal: pagesTotal,
            surahsCompleted: surahsCompleted,
            minutesLast7Days: minutes,
            minutesReclaimed: reclaimed
        )
    }
}
