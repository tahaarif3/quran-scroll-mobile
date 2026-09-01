import Foundation

/// Per-prayer minute offsets applied on top of calculated salah times.
public struct PrayerTimeAdjustments: Codable, Equatable, Sendable {
    /// PrayerName raw value → minutes to add (negative allowed).
    public var minutes: [String: Int]

    public init(minutes: [String: Int] = [:]) {
        self.minutes = minutes
    }

    public static let none = PrayerTimeAdjustments()

    public func offset(for prayer: PrayerName) -> Int {
        minutes[prayer.rawValue] ?? 0
    }

    public func isAdjusted(_ prayer: PrayerName) -> Bool {
        offset(for: prayer) != 0
    }

    public var hasAny: Bool {
        minutes.values.contains { $0 != 0 }
    }

    public mutating func setOffset(_ offsetMinutes: Int, for prayer: PrayerName) {
        if offsetMinutes == 0 {
            minutes.removeValue(forKey: prayer.rawValue)
        } else {
            minutes[prayer.rawValue] = offsetMinutes
        }
    }

    public mutating func resetAll() {
        minutes.removeAll()
    }
}

public extension PrayerTimes {
    func applying(_ adjustments: PrayerTimeAdjustments) -> PrayerTimes {
        PrayerTimes(
            date: date,
            fajr: adjusted(fajr, prayer: .fajr, adjustments: adjustments),
            dhuhr: adjusted(dhuhr, prayer: .dhuhr, adjustments: adjustments),
            asr: adjusted(asr, prayer: .asr, adjustments: adjustments),
            maghrib: adjusted(maghrib, prayer: .maghrib, adjustments: adjustments),
            isha: adjusted(isha, prayer: .isha, adjustments: adjustments)
        )
    }

    private func adjusted(_ time: Date, prayer: PrayerName, adjustments: PrayerTimeAdjustments) -> Date {
        let offset = adjustments.offset(for: prayer)
        guard offset != 0 else { return time }
        return time.addingTimeInterval(TimeInterval(offset * 60))
    }
}

/// Computes salah times with optional user adjustments.
public enum PrayerTimesResolver {
    public static func resolve(
        date: Date = Date(),
        latitude: Double,
        longitude: Double,
        adjustments: PrayerTimeAdjustments = .none,
        timeZone: TimeZone = .current
    ) -> PrayerTimes {
        let base = PrayerTimesCalculator.compute(
            date: date,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
        return base.applying(adjustments)
    }
}

/// Minute offset from a calculated time to a user-picked clock time on the same day.
public enum PrayerTimeOffsetMath {
    public static func offsetMinutes(
        from calculated: Date,
        to picked: Date,
        calendar: Calendar = .current
    ) -> Int {
        let calc = clockMinutes(calculated, calendar: calendar)
        let pick = clockMinutes(picked, calendar: calendar)
        var offset = pick - calc
        while offset > 720 { offset -= 1440 }
        while offset < -720 { offset += 1440 }
        return offset
    }

    public static func adjustedTime(
        calculated: Date,
        offsetMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        guard offsetMinutes != 0 else { return calculated }
        return calculated.addingTimeInterval(TimeInterval(offsetMinutes * 60))
    }

    private static func clockMinutes(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// Reads and writes prayer-time adjustments across SwiftData and the App Group.
public enum PrayerTimeSettings {
    public static func load(
        profile: UserProfile?,
        store: AppGroupStore = .shared
    ) -> PrayerTimeAdjustments {
        if let profile, let fromProfile = decode(profile.prayerTimeOffsetsJSON) {
            return fromProfile
        }
        return store.prayerTimeAdjustments
    }

    public static func save(
        _ adjustments: PrayerTimeAdjustments,
        profile: UserProfile?,
        store: AppGroupStore = .shared
    ) {
        store.prayerTimeAdjustments = adjustments
        profile?.prayerTimeOffsetsJSON = encode(adjustments)
    }

    private static func encode(_ adjustments: PrayerTimeAdjustments) -> String {
        guard let data = try? JSONEncoder().encode(adjustments),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }

    private static func decode(_ json: String) -> PrayerTimeAdjustments? {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PrayerTimeAdjustments.self, from: data) else {
            return nil
        }
        return decoded
    }
}
