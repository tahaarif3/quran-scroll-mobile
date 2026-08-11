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
    case systemPrompt
    case rating
    case planReady
    case paywall
    case appPicker

    public var id: String { rawValue }

    /// Design order: welcome → 2a → 2b → 2c → 2d…2f → 2g…2m → 2n → appPicker → 2o → 2p → 2q → 2r
    public static var flowOrder: [OnboardingStep] {
        [
            .welcome, .howItWorks, .socialProof, .screenTime,
            .reveal, .reframe, .promise,
            .age, .gender, .faith, .arabic, .frequency, .readingStyle, .goals,
            .permissionPrimer, .appPicker, .systemPrompt, .rating, .planReady, .paywall
        ]
    }

    public var progress: Double? {
        switch self {
        case .screenTime: return 0.16
        case .age: return 0.38
        case .gender: return 0.48
        case .faith: return 0.58
        case .arabic: return 0.66
        case .frequency: return 0.74
        case .readingStyle: return 0.82
        case .goals: return 0.92
        default: return nil
        }
    }

    public var showsBack: Bool { self != .welcome }
    public var analyticsName: String { rawValue }
}

public enum ScreenTimeAnswer: String, CaseIterable, Codable, Sendable {
    case under2 = "Less than 2h"
    case hours2to4 = "2–4h"
    case hours4to6 = "4–6h"
    case hours6to8 = "6–8h"
    case over8 = "More than 8h"

    public var hoursPerDay: Double {
        switch self {
        case .under2: return 1.5
        case .hours2to4: return 3
        case .hours4to6: return 5
        case .hours6to8: return 7
        case .over8: return 11 // yields ~25 lifetime years with age 18–24 (design reveal copy)
        }
    }
}

public enum AgeBucket: String, CaseIterable, Codable, Sendable {
    case under18 = "Under 18"
    case age18to24 = "18–24"
    case age25to34 = "25–34"
    case age35to44 = "35–44"
    case age45to54 = "45–54"
    case age55plus = "55+"

    public var remainingLifeYears: Double {
        switch self {
        case .under18: return 60
        case .age18to24: return 55
        case .age25to34: return 48
        case .age35to44: return 40
        case .age45to54: return 32
        case .age55plus: return 25
        }
    }
}

public enum GenderAnswer: String, CaseIterable, Codable, Sendable {
    case man = "Man"
    case woman = "Woman"
    case preferNot = "Prefer not to say"

    public var icon: IQIcon? {
        switch self {
        case .man: return .man
        case .woman: return .woman
        case .preferNot: return nil
        }
    }
}

public enum FaithStage: String, CaseIterable, Codable, Sendable {
    case newMuslim = "New Muslim"
    case practicing = "Practicing"
    case returning = "Returning to faith"
    case exploring = "Exploring"

    public var icon: IQIcon {
        switch self {
        case .newMuslim: return .seed
        case .practicing: return .mosque
        case .returning: return .heart
        case .exploring: return .sparkle
        }
    }
}

public enum ArabicAbility: String, CaseIterable, Codable, Sendable {
    case learningLetters = "Just learning the letters"
    case soundOut = "I can sound out words"
    case comfortably = "I read comfortably"
    case fluent = "Fluent, mashaAllah"
    case translationOnly = "I read translation only"

    public var icon: IQIcon {
        switch self {
        case .learningLetters: return .arabicLetter
        case .soundOut: return .speak
        case .comfortably: return .book
        case .fluent: return .star
        case .translationOnly: return .globe
        }
    }

    public var boostsGoal: Bool {
        self == .comfortably || self == .fluent
    }
}

public enum ReadFrequency: String, CaseIterable, Codable, Sendable {
    case lessThanWeekly = "Less than once a week"
    case days1to2 = "1–2 days"
    case days3to5 = "3–5 days"
    case everyDay = "Every day"

    public var icon: IQIcon {
        switch self {
        case .lessThanWeekly: return .moon
        case .days1to2: return .calendar
        case .days3to5: return .book
        case .everyDay: return .flame
        }
    }

    public var boostsGoal: Bool {
        self == .days3to5 || self == .everyDay
    }
}

public enum ReadingStyleAnswer: String, CaseIterable, Codable, Sendable {
    case arabicTranslation = "Arabic + translation"
    case translationFirst = "Translation first"
    case arabicTransliteration = "Arabic + transliteration"
    case arabicOnly = "Arabic only"
}

public enum GoalAnswer: String, CaseIterable, Codable, Sendable, Identifiable {
    case dailyHabit = "Build a daily reading habit"
    case lessPhone = "Spend less time on my phone"
    case closerToAllah = "Grow closer to Allah"
    case understandBetter = "Understand the Qur'an better"

    public var id: String { rawValue }

    public var icon: IQIcon {
        switch self {
        case .dailyHabit: return .book
        case .lessPhone: return .phoneOff
        case .closerToAllah: return .dua
        case .understandBetter: return .bulb
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
