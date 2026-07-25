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

/// Design copy (25 years / 15 years back / Qur'an in 30 days) is the "More than 8h" case.
/// Assumption: hoursPerDay × 365 × remainingLifeYears.
public enum ProjectionCalculator {
    public static func project(
        screenTime: ScreenTimeAnswer,
        age: AgeBucket = .age18to24
    ) -> ProjectionResult {
        let hours = screenTime.hoursPerDay
        let remaining = age.remainingLifeYears
        let lifetimeHours = hours * 365.0 * remaining
        let yearsLost = max(1, Int((lifetimeHours / (24.0 * 365.0)).rounded()))
        let yearsBack = max(1, Int((Double(yearsLost) * 0.6).rounded()))

        let quranDays: Int
        switch screenTime {
        case .under2: quranDays = 60
        case .hours2to4: quranDays = 45
        case .hours4to6: quranDays = 40
        case .hours6to8: quranDays = 35
        case .over8: quranDays = 30
        }

        return ProjectionResult(
            yearsLost: yearsLost,
            yearsBackToDeen: yearsBack,
            quranDays: quranDays,
            hoursPerDay: hours
        )
    }
}
