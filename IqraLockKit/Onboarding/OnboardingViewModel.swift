import Foundation
import Observation

@Observable
public final class OnboardingViewModel {
    public private(set) var step: OnboardingStep
    public var answers: OnboardingAnswers
    public var selectedAppsCount: Int = 0

    private let draftKey = "iqralock.onboarding.draft"
    private let stepKey = "iqralock.onboarding.step"
    private let analytics: AnalyticsService
    private let defaults: UserDefaults

    public init(
        analytics: AnalyticsService = NoopAnalytics(),
        defaults: UserDefaults = .standard,
        restoreDraft: Bool = true
    ) {
        self.analytics = analytics
        self.defaults = defaults
        if restoreDraft,
           let data = defaults.data(forKey: draftKey),
           let decoded = try? JSONDecoder().decode(OnboardingAnswers.self, from: data) {
            self.answers = decoded
        } else {
            self.answers = OnboardingAnswers()
        }
        if restoreDraft,
           let raw = defaults.string(forKey: stepKey),
           let restored = OnboardingStep(rawValue: raw),
           OnboardingStep.flowOrder.contains(restored) {
            self.step = restored
        } else {
            self.step = .welcome
        }
    }

    public var ctaTitle: String {
        switch step {
        case .welcome: return "See How it Works →"
        case .howItWorks, .socialProof, .screenTime, .age, .gender, .faith,
             .arabic, .frequency, .readingStyle, .goals, .permissionPrimer,
             .appPicker, .systemPrompt, .rating, .reframe:
            return "Continue →"
        case .reveal: return "Wow →"
        case .promise: return "Start Journey →"
        case .planReady: return "Let's Go! →"
        case .paywall: return "Start 3-day free trial →"
        }
    }

    public var ctaEnabled: Bool {
        switch step {
        case .screenTime: return answers.screenTime != nil
        case .age: return answers.age != nil
        case .gender: return answers.gender != nil
        case .faith: return answers.faithStage != nil
        case .arabic: return answers.arabicAbility != nil
        case .frequency: return answers.readFrequency != nil
        case .readingStyle: return answers.readingStyle != nil
        case .goals: return !answers.goals.isEmpty
        case .appPicker: return selectedAppsCount > 0
        default: return true
        }
    }

    public var projection: ProjectionResult {
        ProjectionCalculator.project(
            screenTime: answers.screenTime ?? .over8,
            age: answers.age ?? .age18to24
        )
    }

    public var derivedDailyGoal: Int {
        GoalDeriver.dailyGoalPages(
            arabicAbility: answers.arabicAbility,
            readFrequency: answers.readFrequency,
            goals: answers.goals
        )
    }

    public func onAppear() {
        let index = OnboardingStep.flowOrder.firstIndex(of: step) ?? 0
        analytics.track("onboarding_step_viewed", properties: [
            "step": step.analyticsName,
            "index": index
        ])
    }

    public func next() {
        persistDraft()
        guard let idx = OnboardingStep.flowOrder.firstIndex(of: step),
              idx + 1 < OnboardingStep.flowOrder.count else { return }
        step = OnboardingStep.flowOrder[idx + 1]
        onAppear()
    }

    public func back() {
        guard let idx = OnboardingStep.flowOrder.firstIndex(of: step), idx > 0 else { return }
        step = OnboardingStep.flowOrder[idx - 1]
    }

    public func selectScreenTime(_ value: ScreenTimeAnswer) {
        answers.screenTime = value
        trackAnswer("screen_time", value.rawValue)
        persistDraft()
    }

    public func selectAge(_ value: AgeBucket) {
        answers.age = value
        trackAnswer("age", value.rawValue)
        persistDraft()
    }

    public func selectGender(_ value: GenderAnswer) {
        answers.gender = value
        trackAnswer("gender", value.rawValue)
        persistDraft()
    }

    public func selectFaith(_ value: FaithStage) {
        answers.faithStage = value
        trackAnswer("faith", value.rawValue)
        persistDraft()
    }

    public func selectArabic(_ value: ArabicAbility) {
        answers.arabicAbility = value
        trackAnswer("arabic", value.rawValue)
        persistDraft()
    }

    public func selectFrequency(_ value: ReadFrequency) {
        answers.readFrequency = value
        trackAnswer("frequency", value.rawValue)
        persistDraft()
    }

    public func selectReadingStyle(_ value: ReadingStyleAnswer) {
        answers.readingStyle = value
        trackAnswer("reading_style", value.rawValue)
        persistDraft()
    }

    public func toggleGoal(_ value: GoalAnswer) {
        if let i = answers.goals.firstIndex(of: value) {
            answers.goals.remove(at: i)
        } else {
            answers.goals.append(value)
        }
        trackAnswer("goals", answers.goals.map(\.rawValue).joined(separator: ","))
        persistDraft()
    }

    public func persistDraft() {
        if let data = try? JSONEncoder().encode(answers) {
            defaults.set(data, forKey: draftKey)
        }
        defaults.set(step.rawValue, forKey: stepKey)
    }

    public func clearDraft() {
        defaults.removeObject(forKey: draftKey)
        defaults.removeObject(forKey: stepKey)
    }

    public func completeProfile() -> UserProfileDraft {
        let draft = UserProfileDraft(
            displayName: answers.displayName.isEmpty ? "Yusuf" : answers.displayName,
            dailyGoalPages: derivedDailyGoal,
            readingStyle: answers.readingStyle ?? .arabicTranslation,
            gender: answers.gender,
            faithStage: answers.faithStage,
            arabicAbility: answers.arabicAbility,
            readFrequency: answers.readFrequency,
            goals: answers.goals,
            onboardingCompletedAt: Date()
        )
        clearDraft()
        return draft
    }

    private func trackAnswer(_ question: String, _ value: String) {
        analytics.track("onboarding_answer", properties: [
            "question": question,
            "value": value
        ])
    }
}

public struct UserProfileDraft: Equatable, Sendable {
    public var displayName: String
    public var dailyGoalPages: Int
    public var readingStyle: ReadingStyleAnswer
    public var gender: GenderAnswer?
    public var faithStage: FaithStage?
    public var arabicAbility: ArabicAbility?
    public var readFrequency: ReadFrequency?
    public var goals: [GoalAnswer]
    public var onboardingCompletedAt: Date
}
