import Foundation

/// Five daily prayer times computed locally from coordinates — no network required.
public enum PrayerName: String, CaseIterable, Codable, Sendable, Identifiable {
    case fajr, dhuhr, asr, maghrib, isha

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
}

public struct PrayerTimes: Equatable, Sendable {
    public let date: Date
    public let fajr: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date

    public func time(for prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }

    public var ordered: [(PrayerName, Date)] {
        PrayerName.allCases.map { ($0, time(for: $0)) }
    }

    public func nextPrayer(after now: Date = Date()) -> (PrayerName, Date)? {
        ordered.first { $0.1 > now }
    }
}

/// Muslim World League angles (Fajr 18°, Isha 17°).
public enum PrayerTimesCalculator {
    public static func compute(
        date: Date = Date(),
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current
    ) -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: date)
        let julian = julianDay(for: day, calendar: calendar)
        let decl = sunDeclination(julian: julian)
        let eqt = equationOfTime(julian: julian)
        let tzHours = Double(timeZone.secondsFromGMT(for: day)) / 3600

        let fajr = timeForAngle(
            18, decl: decl, eqt: eqt, latitude: latitude, longitude: longitude,
            tzHours: tzHours, day: day, calendar: calendar, morning: true
        )
        let dhuhr = solarNoon(eqt: eqt, longitude: longitude, tzHours: tzHours, day: day, calendar: calendar)
        let asr = asrTime(
            decl: decl, eqt: eqt, latitude: latitude, longitude: longitude,
            tzHours: tzHours, day: day, calendar: calendar
        )
        let maghrib = timeForAngle(
            0.833, decl: decl, eqt: eqt, latitude: latitude, longitude: longitude,
            tzHours: tzHours, day: day, calendar: calendar, morning: false
        )
        let isha = timeForAngle(
            17, decl: decl, eqt: eqt, latitude: latitude, longitude: longitude,
            tzHours: tzHours, day: day, calendar: calendar, morning: false
        )
        return PrayerTimes(date: day, fajr: fajr, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha)
    }

    private static func julianDay(for date: Date, calendar: Calendar) -> Double {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        var y = Double(c.year ?? 2000)
        var m = Double(c.month ?? 1)
        let d = Double(c.day ?? 1)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + d + b - 1524.5
    }

    private static func sunDeclination(julian: Double) -> Double {
        let d = julian - 2451545.0
        let g = (357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360)
        let q = (280.459 + 0.98564736 * d).truncatingRemainder(dividingBy: 360)
        let l = (q + 1.915 * sin(g * .pi / 180) + 0.020 * sin(2 * g * .pi / 180))
            .truncatingRemainder(dividingBy: 360)
        let e = 23.439 - 0.00000036 * d
        return asin(sin(e * .pi / 180) * sin(l * .pi / 180)) * 180 / .pi
    }

    private static func equationOfTime(julian: Double) -> Double {
        let d = julian - 2451545.0
        let g = (357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360) * .pi / 180
        let q = (280.459 + 0.98564736 * d).truncatingRemainder(dividingBy: 360) * .pi / 180
        let l = q + 0.0172 * sin(g) + 0.0033 * sin(2 * g)
        let e = (23.439 - 0.00000036 * d) * .pi / 180
        let ra = atan2(cos(e) * sin(l), cos(l)) * 180 / .pi
        return (q * 180 / .pi - ra).truncatingRemainder(dividingBy: 360) / 15 * 60
    }

    private static func solarNoon(
        eqt: Double, longitude: Double, tzHours: Double, day: Date, calendar: Calendar
    ) -> Date {
        timeOnDay(day, minutes: 720 - 4 * longitude - eqt + tzHours * 60, calendar: calendar)
    }

    private static func timeForAngle(
        angle: Double, decl: Double, eqt: Double, latitude: Double, longitude: Double,
        tzHours: Double, day: Date, calendar: Calendar, morning: Bool
    ) -> Date {
        let latRad = latitude * .pi / 180
        let declRad = decl * .pi / 180
        let angleRad = angle * .pi / 180
        let cosH = (-sin(angleRad) - sin(latRad) * sin(declRad)) / (cos(latRad) * cos(declRad))
        let h = acos(min(1, max(-1, cosH))) * 180 / .pi / 15
        let noon = 720 - 4 * longitude - eqt + tzHours * 60
        let minutes = morning ? noon - h * 60 : noon + h * 60
        return timeOnDay(day, minutes: minutes, calendar: calendar)
    }

    private static func asrTime(
        decl: Double, eqt: Double, latitude: Double, longitude: Double,
        tzHours: Double, day: Date, calendar: Calendar
    ) -> Date {
        let latRad = latitude * .pi / 180
        let declRad = decl * .pi / 180
        let cot = 1 + tan(abs(latRad - declRad))
        let angle = atan(1 / cot) * 180 / .pi
        return timeForAngle(
            90 - angle, decl: decl, eqt: eqt, latitude: latitude, longitude: longitude,
            tzHours: tzHours, day: day, calendar: calendar, morning: false
        )
    }

    private static func timeOnDay(_ day: Date, minutes: Double, calendar: Calendar) -> Date {
        var normalized = minutes.truncatingRemainder(dividingBy: 1440)
        if normalized < 0 { normalized += 1440 }
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = Int(normalized) / 60
        comps.minute = Int(normalized) % 60
        comps.second = 0
        return calendar.date(from: comps) ?? day
    }
}
