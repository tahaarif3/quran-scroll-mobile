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
        public static let launchInProgress = "launchInProgress"
        public static let consecutiveLaunchFailures = "consecutiveLaunchFailures"
        public static let ayahsReadToday = "ayahsReadToday"
        public static let ayahsPerPage = "ayahsPerPage"
        public static let lastAyahReadAt = "lastAyahReadAt"
        public static let ayahUnlockMinutes = "ayahUnlockMinutes"
        public static let ayahRejectedAt = "ayahRejectedAt"
        public static let totalPagesRead = "totalPagesRead"
        public static let khatmCount = "khatmCount"
    }

    /// Minutes of access a single ayah buys. Adjustable — it is the exchange rate between
    /// reading and scrolling, and the single most consequential number in the app.
    public var ayahUnlockMinutes: Int {
        get {
            let v = defaults.integer(forKey: Key.ayahUnlockMinutes)
            return v > 0 ? v : 30
        }
        set { defaults.set(max(1, newValue), forKey: Key.ayahUnlockMinutes) }
    }

    /// When a read was refused for arriving too fast, so the shield can explain itself instead
    /// of appearing to ignore the tap.
    public var ayahRejectedAt: Date? {
        get { defaults.object(forKey: Key.ayahRejectedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.ayahRejectedAt) }
    }

    /// Lifetime pages, never reset by the day roll — the khatm counter reads from this.
    public var totalPagesRead: Int {
        get { defaults.integer(forKey: Key.totalPagesRead) }
        set { defaults.set(newValue, forKey: Key.totalPagesRead) }
    }

    /// Completed readings of the whole Qur'an.
    public var khatmCount: Int {
        get { defaults.integer(forKey: Key.khatmCount) }
        set { defaults.set(newValue, forKey: Key.khatmCount) }
    }

    public static let pagesInMushaf = 604

    /// Pages into the current khatm, 0..<604.
    public var pagesIntoKhatm: Int { totalPagesRead % Self.pagesInMushaf }
    public var pagesToKhatm: Int { Self.pagesInMushaf - pagesIntoKhatm }
    public var khatmProgress: Double {
        Double(pagesIntoKhatm) / Double(Self.pagesInMushaf)
    }

    /// Opens the apps for `ayahUnlockMinutes`. Extends rather than replaces, so reading two
    /// ayahs back to back is worth two windows rather than resetting the first.
    public func grantAyahWindow(now: Date = Date()) {
        let base = max(now, unlockedUntil ?? now)
        unlockedUntil = base.addingTimeInterval(TimeInterval(ayahUnlockMinutes * 60))
        isLockedNow = false
    }

    /// Set at launch, cleared once the app has run long enough to be considered healthy. If it
    /// is still set at the next launch, the previous one died before getting there.
    public var launchInProgress: Bool {
        get { defaults.bool(forKey: Key.launchInProgress) }
        set { defaults.set(newValue, forKey: Key.launchInProgress) }
    }

    public var consecutiveLaunchFailures: Int {
        get { defaults.integer(forKey: Key.consecutiveLaunchFailures) }
        set { defaults.set(newValue, forKey: Key.consecutiveLaunchFailures) }
    }

    public var pagesReadToday: Int {
        get { defaults.integer(forKey: Key.pagesReadToday) }
        set { defaults.set(newValue, forKey: Key.pagesReadToday) }
    }

    /// Ayahs read today that have not yet rolled into a whole page.
    ///
    /// The goal stays denominated in pages — pages are what ladder up to a khatm — but progress
    /// accrues an ayah at a time, so reading is never all-or-nothing. A single ayah from the
    /// shield moves the bar.
    public var ayahsReadToday: Int {
        get { defaults.integer(forKey: Key.ayahsReadToday) }
        set { defaults.set(newValue, forKey: Key.ayahsReadToday) }
    }

    /// How many loose ayahs count as one page. The mushaf averages roughly ten (6,236 ayahs over
    /// 604 pages), which is the default. User-adjustable because it is the dial that decides how
    /// much a single tap is worth.
    public var ayahsPerPage: Int {
        get {
            let v = defaults.integer(forKey: Key.ayahsPerPage)
            return v > 0 ? v : 10
        }
        set { defaults.set(max(1, newValue), forKey: Key.ayahsPerPage) }
    }

    public var lastAyahReadAt: Date? {
        get { defaults.object(forKey: Key.lastAyahReadAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastAyahReadAt) }
    }

    /// Fraction of the next page already earned by loose ayahs, for the progress ring.
    public var partialPageProgress: Double {
        min(1, Double(ayahsReadToday) / Double(max(1, ayahsPerPage)))
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
            ayahsReadToday = 0
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

    /// Credits one page to today, to the lifetime total, and to the khatm.
    ///
    /// Every path that completes a page must go through here. The khatm counters used to be
    /// incremented only inside `recordAyah`, so pages read in the reader — the app's main way of
    /// reading — advanced the daily goal but never the khatm, while tapping ayahs on the shield
    /// did. Exactly backwards, and invisible until someone compared the two screens.
    public func creditPage() {
        pagesReadToday += 1
        totalPagesRead += 1
        if totalPagesRead % Self.pagesInMushaf == 0 {
            khatmCount += 1
        }
    }

    public struct AyahRecord: Equatable, Sendable {
        public let counted: Bool
        public let ayahsIntoPage: Int
        public let ayahsPerPage: Int
        public let pagesToday: Int
        public let goalMet: Bool
    }

    /// Minimum gap between two ayahs that both count. The shield's read button is a single tap,
    /// so without this the whole day's goal is a few seconds of tapping.
    public static let minimumAyahInterval: TimeInterval = 5

    /// Records one ayah and rolls it into a page every `ayahsPerPage`.
    ///
    /// Lives on the store rather than the coordinator because the ShieldAction extension needs
    /// exactly this and cannot afford to build a coordinator — two implementations of the
    /// roll-into-a-page rule would drift, and the app and the lock screen disagreeing about how
    /// much you have read is the worst possible bug in this app.
    @discardableResult
    public func recordAyah(now: Date = Date()) -> AyahRecord {
        ensureCurrentDay(now: now)

        if let last = lastAyahReadAt, now.timeIntervalSince(last) < Self.minimumAyahInterval {
            return AyahRecord(
                counted: false,
                ayahsIntoPage: ayahsReadToday,
                ayahsPerPage: ayahsPerPage,
                pagesToday: pagesReadToday,
                goalMet: goalMetToday
            )
        }
        lastAyahReadAt = now
        ayahRejectedAt = nil
        ayahsReadToday += 1
        if ayahsReadToday >= ayahsPerPage {
            ayahsReadToday -= ayahsPerPage
            creditPage()
        }
        return AyahRecord(
            counted: true,
            ayahsIntoPage: ayahsReadToday,
            ayahsPerPage: ayahsPerPage,
            pagesToday: pagesReadToday,
            goalMet: goalMetToday
        )
    }

    #if DEBUG
    /// Wipe every key this store owns, returning the app-group side to a first-run state.
    /// Debug builds only — this is the reset path for TestFlight/device testing, where
    /// reinstalling to re-run onboarding is slow.
    public func resetAllForDebug() {
        for key in [
            Key.pagesReadToday, Key.dailyGoalPages, Key.isLockedNow, Key.unlockedUntil,
            Key.emergencyPassesRemaining, Key.emergencyPassesMonthKey, Key.selectedAppsData,
            Key.selectedAppsCount, Key.userDisplayName, Key.dayKey, Key.pendingDeepLink,
            Key.launchInProgress, Key.consecutiveLaunchFailures,
            Key.ayahsReadToday, Key.ayahsPerPage, Key.lastAyahReadAt
        ] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
