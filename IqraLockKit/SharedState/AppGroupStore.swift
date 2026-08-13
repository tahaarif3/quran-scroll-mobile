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
        public static let khatmCursor = "khatmCursor"
        public static let cachedAyahs = "cachedAyahs"
        public static let dailyGoalAyahs = "dailyGoalAyahs"
    }

    public struct CachedAyah: Codable, Equatable, Sendable {
        public let id: Int
        public let verseKey: String
        public let arabic: String
        public let translation: String

        public init(id: Int, verseKey: String, arabic: String, translation: String) {
            self.id = id
            self.verseKey = verseKey
            self.arabic = arabic
            self.translation = translation
        }
    }

    /// A window of upcoming ayahs, written by the app and read by the shield.
    ///
    /// The shield extension opened the bundled SQLite directly and got nothing — it fell back to
    /// the bare progress line with no ayah at all. Rather than debug a database inside an
    /// extension with a hard memory and time budget, the app writes plain strings here and the
    /// extension only ever reads them. It also caches a window rather than a single ayah, so the
    /// shield can advance several times without the app ever running.
    public var cachedAyahs: [CachedAyah] {
        get {
            guard let data = defaults.data(forKey: Key.cachedAyahs) else { return [] }
            return (try? decoder.decode([CachedAyah].self, from: data)) ?? []
        }
        set { defaults.set(try? encoder.encode(newValue), forKey: Key.cachedAyahs) }
    }

    /// The cached ayah for the current cursor, if the window still covers it.
    public var cachedAyahAtCursor: CachedAyah? {
        cachedAyahs.first { $0.id == khatmCursor }
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
    public static let ayahsInMushaf = 6236

    /// The next ayah to read, as a global id in 1...6236.
    ///
    /// One cursor shared by the reader and the shield. It has to live here rather than in
    /// SwiftData because the shield extension cannot reach SwiftData, and a shield that served
    /// ayahs from a separate list is what made the khatm counter dishonest: eighteen short
    /// verses on rotation, each tenth tap claiming another page of the Qur'an had been read.
    public var khatmCursor: Int {
        get {
            let v = defaults.integer(forKey: Key.khatmCursor)
            return v > 0 ? v : 1
        }
        set { defaults.set(min(max(1, newValue), Self.ayahsInMushaf), forKey: Key.khatmCursor) }
    }

    /// Moves the cursor forward, rolling over into a completed khatm at the end of the mushaf.
    public func advanceKhatmCursor(by count: Int = 1) {
        guard count > 0 else { return }
        var next = khatmCursor + count
        while next > Self.ayahsInMushaf {
            next -= Self.ayahsInMushaf
            khatmCount += 1
        }
        khatmCursor = next
    }

    /// Only ever moves forward — jumping back to re-read an earlier surah shouldn't undo
    /// progress through the mushaf.
    public func advanceKhatmCursor(toAyahID id: Int) {
        guard id > khatmCursor else { return }
        advanceKhatmCursor(by: id - khatmCursor)
    }

    public var ayahsIntoKhatm: Int { khatmCursor - 1 }
    public var ayahsToKhatm: Int { Self.ayahsInMushaf - ayahsIntoKhatm }
    public var khatmProgress: Double {
        Double(ayahsIntoKhatm) / Double(Self.ayahsInMushaf)
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

    /// The daily goal, in ayahs.
    ///
    /// Authoritative because it is continuous: a goal of one ayah and a goal of ten pages are the
    /// same setting at different points, where whole pages could not express anything under a
    /// page. `dailyGoalPages` is kept as a derived view of this so existing callers still work.
    public var dailyGoalAyahs: Int {
        get {
            let v = defaults.integer(forKey: Key.dailyGoalAyahs)
            return v > 0 ? v : 3 * ayahsPerPage
        }
        set { defaults.set(max(1, newValue), forKey: Key.dailyGoalAyahs) }
    }

    /// Everything read today expressed in ayahs, so partial pages count toward the goal.
    public var totalAyahsToday: Int {
        pagesReadToday * ayahsPerPage + ayahsReadToday
    }

    public var dailyGoalPages: Int {
        get {
            let derived = Int(ceil(Double(dailyGoalAyahs) / Double(max(1, ayahsPerPage))))
            return max(1, derived)
        }
        set { dailyGoalAyahs = max(1, newValue) * ayahsPerPage }
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

    /// Measured in ayahs, so a goal smaller than a page can be met at all and a partial page
    /// counts toward one that isn't.
    public var goalMetToday: Bool {
        totalAyahsToday >= dailyGoalAyahs
    }

    /// The goal as a person would say it: ayahs below a page, pages above.
    public var goalDescription: String {
        if dailyGoalAyahs < ayahsPerPage {
            return dailyGoalAyahs == 1 ? "1 ayah" : "\(dailyGoalAyahs) ayahs"
        }
        let pages = dailyGoalPages
        return pages == 1 ? "1 page" : "\(pages) pages"
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

    /// Credits one page to today and to the lifetime total.
    ///
    /// Khatm progress is deliberately *not* incremented here — it is driven by the cursor, so
    /// that it only ever reflects ayahs actually passed through in order. Callers that know
    /// which ayahs were covered advance the cursor themselves.
    public func creditPage() {
        pagesReadToday += 1
        totalPagesRead += 1
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
            Key.ayahsReadToday, Key.ayahsPerPage, Key.lastAyahReadAt,
            Key.ayahUnlockMinutes, Key.ayahRejectedAt, Key.totalPagesRead,
            Key.khatmCount, Key.khatmCursor
        ] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
