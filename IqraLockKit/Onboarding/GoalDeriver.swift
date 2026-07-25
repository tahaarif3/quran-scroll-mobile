import Foundation

/// Maps onboarding answers → `dailyGoalPages` (2–5).
/// Baseline 3; +1 if frequency is 3–5 days / every day; +1 if Arabic comfortably/fluent; floor 2, cap 5.
public enum GoalDeriver {
    public static func dailyGoalPages(
        arabicAbility: ArabicAbility?,
        readFrequency: ReadFrequency?,
        goals: [GoalAnswer] = []
    ) -> Int {
        var pages = 3
        if readFrequency?.boostsGoal == true { pages += 1 }
        if arabicAbility?.boostsGoal == true { pages += 1 }
        // Completing a khatm nudges toward the higher end when not already boosted.
        if goals.contains(.completeKhatm) && pages < 4 { pages += 1 }
        if goals.contains(.finishJuz) == false && readFrequency == .rarely {
            pages -= 1
        }
        return min(5, max(2, pages))
    }
}
