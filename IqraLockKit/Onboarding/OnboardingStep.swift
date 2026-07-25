import Foundation

public enum OnboardingStep: String, CaseIterable, Codable, Sendable, Identifiable {
    case welcome
    case howItWorks
    case socialProof
    case screenTime
    case reveal
    case reframe
    case promise
    case age
    case gender
    case faith
    case arabic
    case frequency
    case readingStyle
    case goals
    case permissionPrimer
    case appPicker
    case systemPrompt
    case rating
    case planReady
    case paywall

    public var id: String { rawValue }

    /// Non-uniform progress values from the design (nil = no bar).
    public var progress: Double? {
        switch self {
        case .welcome, .howItWorks, .socialProof, .reveal, .reframe, .promise,
             .permissionPrimer, .appPicker, .systemPrompt, .rating, .planReady, .paywall:
            return nil
        case .screenTime: return 0.16
        case .age: return 0.38
        case .gender: return 0.48
        case .faith: return 0.58
        case .arabic: return 0.66
        case .frequency: return 0.74
        case .readingStyle: return 0.82
        case .goals: return 0.92
        }
    }

    public var showsBack: Bool {
        self != .welcome
    }

    public var analyticsName: String { rawValue }
}

public enum ScreenTimeAnswer: String, CaseIterable, Codable, Sendable {
    case under2 = "Less than 2h"
    case hours2to4 = "2–4 hours"
    case hours4to8 = "4–8 hours"
    case over8 = "More than 8h"

    public var hoursPerDay: Double {
        switch self {
        case .under2: return 1.5
        case .hours2to4: return 3
        case .hours4to8: return 6
        case .over8: return 9
        }
    }
}

public enum AgeBucket: String, CaseIterable, Codable, Sendable {
    case under18 = "Under 18"
    case age18to24 = "18–24"
    case age25to34 = "25–34"
    case age35to44 = "35–44"
    case age45plus = "45+"

    /// Remaining life years assumption for projection (product heuristic, not actuarial).
    public var remainingLifeYears: Double {
        switch self {
        case .under18: return 60
        case .age18to24: return 55
        case .age25to34: return 48
        case .age35to44: return 40
        case .age45plus: return 30
        }
    }
}

public enum GenderAnswer: String, CaseIterable, Codable, Sendable {
    case brother = "Brother"
    case sister = "Sister"
    case preferNot = "Prefer not to say"
}

public enum FaithStage: String, CaseIterable, Codable, Sendable {
    case reconnecting = "Reconnecting"
    case practicing = "Practicing"
    case deepening = "Deepening"
    case newMuslim = "New to Islam"
}

public enum ArabicAbility: String, CaseIterable, Codable, Sendable {
    case notYet = "Not yet"
    case some = "I know some"
    case comfortably = "I read comfortably"
    case fluent = "Fluent"

    public var boostsGoal: Bool {
        self == .comfortably || self == .fluent
    }
}

public enum ReadFrequency: String, CaseIterable, Codable, Sendable {
    case rarely = "Rarely"
    case days1to2 = "1–2 days / week"
    case days3to5 = "3–5 days / week"
    case everyDay = "Every day"

    public var boostsGoal: Bool {
        self == .days3to5 || self == .everyDay
    }
}

public enum ReadingStyleAnswer: String, CaseIterable, Codable, Sendable {
    case arabicOnly = "Arabic only"
    case arabicTranslation = "Arabic + translation"
    case arabicTransliteration = "Arabic + transliteration"
    case allThree = "Arabic + translation + transliteration"
}

public enum GoalAnswer: String, CaseIterable, Codable, Sendable, Identifiable {
    case finishJuz = "Finish a juz"
    case dailyHabit = "Build a daily habit"
    case understandMeaning = "Understand the meaning"
    case completeKhatm = "Complete a khatm"
    case lessPhone = "Spend less time on my phone"
    case closerToDeen = "Feel closer to my deen"

    public var id: String { rawValue }
    public var emoji: String {
        switch self {
        case .finishJuz: return "📖"
        case .dailyHabit: return "🌅"
        case .understandMeaning: return "💡"
        case .completeKhatm: return "🏁"
        case .lessPhone: return "📵"
        case .closerToDeen: return "🕊️"
        }
    }
}

public struct OnboardingAnswers: Codable, Equatable, Sendable {
    public var screenTime: ScreenTimeAnswer?
    public var age: AgeBucket?
    public var gender: GenderAnswer?
    public var faithStage: FaithStage?
    public var arabicAbility: ArabicAbility?
    public var readFrequency: ReadFrequency?
    public var readingStyle: ReadingStyleAnswer?
    public var goals: [GoalAnswer]
    public var displayName: String

    public init(
        screenTime: ScreenTimeAnswer? = nil,
        age: AgeBucket? = nil,
        gender: GenderAnswer? = nil,
        faithStage: FaithStage? = nil,
        arabicAbility: ArabicAbility? = nil,
        readFrequency: ReadFrequency? = nil,
        readingStyle: ReadingStyleAnswer? = nil,
        goals: [GoalAnswer] = [],
        displayName: String = ""
    ) {
        self.screenTime = screenTime
        self.age = age
        self.gender = gender
        self.faithStage = faithStage
        self.arabicAbility = arabicAbility
        self.readFrequency = readFrequency
        self.readingStyle = readingStyle
        self.goals = goals
        self.displayName = displayName
    }
}
