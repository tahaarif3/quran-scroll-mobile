import Foundation
import SwiftData

@Model
public final class UserProfile {
    public var displayName: String
    public var dailyGoalPages: Int
    public var readingStyleRaw: String
    public var genderRaw: String?
    public var faithStageRaw: String?
    public var arabicAbilityRaw: String?
    public var readFrequencyRaw: String?
    public var goalsRaw: String
    public var reminderHour: Int
    public var reminderMinute: Int
    public var arabicTextSize: Double
    public var translationId: Int
    public var onboardingCompletedAt: Date?
    public var createdAt: Date

    public init(from draft: UserProfileDraft) {
        self.displayName = draft.displayName
        self.dailyGoalPages = draft.dailyGoalPages
        self.readingStyleRaw = draft.readingStyle.rawValue
        self.genderRaw = draft.gender?.rawValue
        self.faithStageRaw = draft.faithStage?.rawValue
        self.arabicAbilityRaw = draft.arabicAbility?.rawValue
        self.readFrequencyRaw = draft.readFrequency?.rawValue
        self.goalsRaw = draft.goals.map(\.rawValue).joined(separator: "|")
        self.reminderHour = 21
        self.reminderMinute = 0
        self.arabicTextSize = 26
        self.translationId = 20
        self.onboardingCompletedAt = draft.onboardingCompletedAt
        self.createdAt = Date()
    }

    public init(
        displayName: String = "Friend",
        dailyGoalPages: Int = 3,
        readingStyle: ReadingStyleAnswer = .arabicTranslation
    ) {
        self.displayName = displayName
        self.dailyGoalPages = dailyGoalPages
        self.readingStyleRaw = readingStyle.rawValue
        self.genderRaw = nil
        self.faithStageRaw = nil
        self.arabicAbilityRaw = nil
        self.readFrequencyRaw = nil
        self.goalsRaw = ""
        self.reminderHour = 21
        self.reminderMinute = 0
        self.arabicTextSize = 26
        self.translationId = 20
        self.onboardingCompletedAt = nil
        self.createdAt = Date()
    }

    public var readingStyle: ReadingStyleAnswer {
        ReadingStyleAnswer(rawValue: readingStyleRaw) ?? .arabicTranslation
    }
}

@Model
public final class DailyRecord {
    public var day: Date
    public var pagesRead: Int
    public var minutesRead: Int
    public var goalMet: Bool
    public var goalPages: Int

    public init(day: Date, pagesRead: Int = 0, minutesRead: Int = 0, goalMet: Bool = false, goalPages: Int = 3) {
        self.day = Calendar.current.startOfDay(for: day)
        self.pagesRead = pagesRead
        self.minutesRead = minutesRead
        self.goalMet = goalMet
        self.goalPages = goalPages
    }
}

@Model
public final class ReadingSession {
    public var startedAt: Date
    public var endedAt: Date?
    public var pagesMarked: Int
    public var surahNumber: Int
    public var startAyah: Int

    public init(startedAt: Date = Date(), pagesMarked: Int = 0, surahNumber: Int = 1, startAyah: Int = 1) {
        self.startedAt = startedAt
        self.endedAt = nil
        self.pagesMarked = pagesMarked
        self.surahNumber = surahNumber
        self.startAyah = startAyah
    }
}

@Model
public final class Bookmark {
    public var surahNumber: Int
    public var ayahNumber: Int
    public var createdAt: Date
    public var note: String

    public init(surahNumber: Int, ayahNumber: Int, note: String = "") {
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.createdAt = Date()
        self.note = note
    }
}

@Model
public final class ReadingPosition {
    public var surahNumber: Int
    public var ayahNumber: Int
    public var pageNumber: Int
    public var updatedAt: Date

    public init(surahNumber: Int = 67, ayahNumber: Int = 1, pageNumber: Int = 562) {
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.pageNumber = pageNumber
        self.updatedAt = Date()
    }
}
