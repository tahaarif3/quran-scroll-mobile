import Foundation

/// Shared schema between the app and all three Screen Time extensions.
/// Only channel for progress, shield state, and emergency passes.
public final class AppGroupStore: @unchecked Sendable {
    public static let shared = AppGroupStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String = AppGroupID.identifier) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public enum Key {
        public static let pagesReadToday = "pagesReadToday"
        public static let dailyGoalPages = "dailyGoalPages"
        public static let isLockedNow = "isLockedNow"
        public static let unlockedUntil = "unlockedUntil"
        public static let emergencyPassesRemaining = "emergencyPassesRemaining"
        public static let emergencyPassesMonthKey = "emergencyPassesMonthKey"
        public static let selectedAppsData = "selectedAppsData"
        public static let selectedAppsCount = "selectedAppsCount"
        public static let userDisplayName = "userDisplayName"
        public static let dayKey = "dayKey"
        public static let pendingDeepLink = "pendingDeepLink"
    }

    public var pagesReadToday: Int {
        get { defaults.integer(forKey: Key.pagesReadToday) }
        set { defaults.set(newValue, forKey: Key.pagesReadToday) }
    }

    public var dailyGoalPages: Int {
        get {
            let v = defaults.integer(forKey: Key.dailyGoalPages)
            return v > 0 ? v : 3
        }
        set { defaults.set(newValue, forKey: Key.dailyGoalPages) }
    }

    public var isLockedNow: Bool {
        get { defaults.bool(forKey: Key.isLockedNow) }
        set { defaults.set(newValue, forKey: Key.isLockedNow) }
    }

    public var unlockedUntil: Date? {
        get { defaults.object(forKey: Key.unlockedUntil) as? Date }
        set { defaults.set(newValue, forKey: Key.unlockedUntil) }
    }

    public var emergencyPassesRemaining: Int {
        get { defaults.integer(forKey: Key.emergencyPassesRemaining) }
        set { defaults.set(newValue, forKey: Key.emergencyPassesRemaining) }
    }

    public var userDisplayName: String {
        get { defaults.string(forKey: Key.userDisplayName) ?? "Friend" }
        set { defaults.set(newValue, forKey: Key.userDisplayName) }
    }

    public var dayKey: String {
        get { defaults.string(forKey: Key.dayKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.dayKey) }
    }

    public var pendingDeepLink: String? {
        get { defaults.string(forKey: Key.pendingDeepLink) }
        set { defaults.set(newValue, forKey: Key.pendingDeepLink) }
    }

    public var selectedAppsData: Data? {
        get { defaults.data(forKey: Key.selectedAppsData) }
        set { defaults.set(newValue, forKey: Key.selectedAppsData) }
    }

    public var selectedAppsCount: Int {
        get { defaults.integer(forKey: Key.selectedAppsCount) }
        set { defaults.set(newValue, forKey: Key.selectedAppsCount) }
    }

    public var pagesRemaining: Int {
        max(0, dailyGoalPages - pagesReadToday)
    }

    public var goalMetToday: Bool {
        pagesReadToday >= dailyGoalPages
    }

    /// Call at midnight reset / foreground. Resets day counters when the local date changes.
    public func ensureCurrentDay(now: Date = Date(), calendar: Calendar = .current) {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: now)
        if dayKey != key {
            dayKey = key
            pagesReadToday = 0
            isLockedNow = true
            unlockedUntil = nil
        }
        resetEmergencyPassesIfNeeded(now: now, calendar: calendar)
    }

    public func resetEmergencyPassesIfNeeded(now: Date = Date(), calendar: Calendar = .current, monthlyAllowance: Int = 3) {
        let comps = calendar.dateComponents([.year, .month], from: now)
        let monthKey = "\(comps.year ?? 0)-\(comps.month ?? 0)"
        let stored = defaults.string(forKey: Key.emergencyPassesMonthKey) ?? ""
        if stored != monthKey {
            defaults.set(monthKey, forKey: Key.emergencyPassesMonthKey)
            emergencyPassesRemaining = monthlyAllowance
        }
    }

    public func shieldSubtitle() -> String {
        "\(pagesReadToday) of \(dailyGoalPages) pages read · \(pagesRemaining) to go"
    }

    #if DEBUG
    /// Wipe every key this store owns, returning the app-group side to a first-run state.
    /// Debug builds only — this is the reset path for TestFlight/device testing, where
    /// reinstalling to re-run onboarding is slow.
    public func resetAllForDebug() {
        for key in [
            Key.pagesReadToday, Key.dailyGoalPages, Key.isLockedNow, Key.unlockedUntil,
            Key.emergencyPassesRemaining, Key.emergencyPassesMonthKey, Key.selectedAppsData,
            Key.selectedAppsCount, Key.userDisplayName, Key.dayKey, Key.pendingDeepLink
        ] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
