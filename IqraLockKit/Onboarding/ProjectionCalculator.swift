import Foundation

public struct ProjectionResult: Equatable, Sendable {
    public let yearsLost: Int
    public let yearsBackToDeen: Int
    public let quranDays: Int
    public let hoursPerDay: Double

    public init(yearsLost: Int, yearsBackToDeen: Int, quranDays: Int, hoursPerDay: Double) {
        self.yearsLost = yearsLost
        self.yearsBackToDeen = yearsBackToDeen
        self.quranDays = quranDays
        self.hoursPerDay = hoursPerDay
    }
}

/// Pure function: screen-time answer → reveal figures.
/// Assumption: `hoursPerDay × 365 × remainingLifeYears` (from age bucket).
/// Design copy (25 years / 15 years back / Qur'an in 30 days) is the "More than 8h" case
/// with a mid adult age — we scale other answers so a 2h/day user isn't told they'll lose 25 years.
public enum ProjectionCalculator {
    public static func project(
        screenTime: ScreenTimeAnswer,
        age: AgeBucket = .age25to34
    ) -> ProjectionResult {
        let hours = screenTime.hoursPerDay
        let remaining = age.remainingLifeYears
        let lifetimeHours = hours * 365.0 * remaining
        let yearsLost = Int((lifetimeHours / (24.0 * 365.0)).rounded())

        // "Years back to your deen" — framed as reclaimable portion (~60% of lost years).
        let yearsBack = max(1, Int((Double(yearsLost) * 0.6).rounded()))

        // Qur'an completion estimate: more phone time → more aggressive daily reading pitch.
        let quranDays: Int
        switch screenTime {
        case .under2: quranDays = 60
        case .hours2to4: quranDays = 45
        case .hours4to8: quranDays = 35
        case .over8: quranDays = 30
        }

        return ProjectionResult(
            yearsLost: max(1, yearsLost),
            yearsBackToDeen: yearsBack,
            quranDays: quranDays,
            hoursPerDay: hours
        )
    }
}
