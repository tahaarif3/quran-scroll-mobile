import Foundation

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
import DeviceActivity
#endif

public enum ScreenTimeAuthStatus: String, Sendable {
    case notDetermined
    case approved
    case denied
}

public protocol ScreenTimeService: AnyObject, Sendable {
    var authStatus: ScreenTimeAuthStatus { get }
    var selectedAppCount: Int { get }
    func requestAuthorization() async throws
    func persistSelectionCount(_ count: Int)
    func applyShield()
    func clearShield()
    func scheduleMidnightReset()
    /// Re-applies the shield when a timed unlock window expires. ManagedSettings has no expiry
    /// of its own, so without this a window lasts until something else puts the shield back.
    func scheduleReshield(at date: Date)
    func consumeEmergencyPass(durationMinutes: Int) -> Bool
}

/// Whether the FamilyControls/ManagedSettings runtime is actually usable in this process.
///
/// `#if canImport(FamilyControls)` only gates *compilation*. The Simulator compiles the
/// framework in and then traps when `ManagedSettingsStore` is constructed, and so does any
/// build missing the `com.apple.developer.family-controls` entitlement. Every touch of a
/// ManagedSettings type must be gated on this at runtime.
public enum ScreenTimeAvailability {
    public static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #elseif canImport(FamilyControls)
        return true
        #else
        return false
        #endif
    }
}

/// Production service. Every FamilyControls type is created on demand and gated on
/// `ScreenTimeAvailability` — never stored, never built at init. See `clearShield()`.
public final class FamilyControlsScreenTimeService: ScreenTimeService, @unchecked Sendable {
    private let store: AppGroupStore
    private let analytics: AnalyticsService

    public init(store: AppGroupStore = .shared, analytics: AnalyticsService = NoopAnalytics()) {
        self.store = store
        self.analytics = analytics
    }

    #if canImport(FamilyControls)
    /// Built on demand, never stored. Constructing `ManagedSettingsStore` eagerly is what
    /// crashed the app on the post-paywall transition: `TabView` builds every tab's view
    /// value up front, so a service held as a view's stored property ran this at view-tree
    /// construction time, before any runtime check could intervene.
    /// Also gated on authorization: a device build without a provisioned
    /// `com.apple.developer.family-controls` entitlement can never reach `.approved`, and there
    /// is nothing to shield when the user has not authorized us anyway.
    private var managedSettings: ManagedSettingsStore? {
        guard ScreenTimeAvailability.isSupported, authStatus == .approved else { return nil }
        return ManagedSettingsStore()
    }

    private var center: AuthorizationCenter? {
        guard ScreenTimeAvailability.isSupported else { return nil }
        return AuthorizationCenter.shared
    }
    #endif

    public var authStatus: ScreenTimeAuthStatus {
        #if canImport(FamilyControls)
        guard let center else { return .notDetermined }
        switch center.authorizationStatus {
        case .approved: return .approved
        case .denied: return .denied
        default: return .notDetermined
        }
        #else
        return .notDetermined
        #endif
    }

    /// Tokens are opaque, so the count is persisted alongside them when the picker saves.
    public var selectedAppCount: Int { store.selectedAppsCount }

    public func requestAuthorization() async throws {
        #if canImport(FamilyControls)
        guard let center else {
            analytics.track("screentime_auth_result", properties: ["status": "unsupported"])
            return
        }
        try await center.requestAuthorization(for: .individual)
        analytics.track("screentime_auth_result", properties: [
            "status": authStatus.rawValue
        ])
        #else
        analytics.track("screentime_auth_result", properties: ["status": "unsupported"])
        #endif
    }

    /// Records how many apps the user picked. Deliberately does *not* touch
    /// `store.selectedAppsData` — that key holds the encoded `FamilyActivitySelection` and nothing
    /// else. Writing a count-only blob there previously made the key unreadable as a selection,
    /// so the shield had nothing to apply even once a real picker existed.
    public func persistSelectionCount(_ count: Int) {
        store.selectedAppsCount = count
        analytics.track("apps_selected", properties: ["count": count])
    }

    public func applyShield() {
        store.ensureCurrentDay()
        store.isLockedNow = true
        store.unlockedUntil = nil
        #if canImport(FamilyControls)
        // This is what actually blocks apps. Setting `isLockedNow` above only records intent —
        // until `shield.applications` is populated, iOS has been told nothing and every selected
        // app opens normally.
        guard let managedSettings,
              let selection = FamilyActivitySelectionStore.load(from: store) else { return }
        managedSettings.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        managedSettings.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        #endif
    }

    public func clearShield() {
        store.isLockedNow = false
        #if canImport(FamilyControls)
        managedSettings?.shield.applications = nil
        managedSettings?.shield.applicationCategories = nil
        #endif
    }

    public func scheduleMidnightReset() {
        #if canImport(FamilyControls)
        guard ScreenTimeAvailability.isSupported, authStatus == .approved else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        try? center.startMonitoring(.daily, during: schedule)
        #endif
    }

    public func scheduleReshield(at date: Date) {
        #if canImport(FamilyControls)
        guard ScreenTimeAvailability.isSupported, authStatus == .approved else { return }
        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: Date()),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: date),
            repeats: false
        )
        let center = DeviceActivityCenter()
        // Stopped before it is restarted. Calling `startMonitoring` on an activity already being
        // monitored makes iOS end the running interval, and `intervalDidEnd` is what puts the
        // shield back — so extending a window by reading a second ayah re-locked everything
        // instead. The monitor now checks the clock too; this keeps the callback from firing at
        // all.
        center.stopMonitoring([.emergencyReshield])
        try? center.startMonitoring(.emergencyReshield, during: schedule)
        #endif
    }

    #if DEBUG
    /// Short schedule so the midnight re-shield can be verified in minutes rather than by
    /// waiting for a real day roll.
    public func scheduleDebugReshield(minutes: Int = 2) {
        #if canImport(FamilyControls)
        guard ScreenTimeAvailability.isSupported, authStatus == .approved else { return }
        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        var end = now
        end.minute = (end.minute ?? 0) + minutes
        let schedule = DeviceActivitySchedule(intervalStart: now, intervalEnd: end, repeats: false)
        try? DeviceActivityCenter().startMonitoring(.debugShort, during: schedule)
        #endif
    }
    #endif

    public func consumeEmergencyPass(durationMinutes: Int = 15) -> Bool {
        store.resetEmergencyPassesIfNeeded()
        guard store.emergencyPassesRemaining > 0 else { return false }
        store.emergencyPassesRemaining -= 1
        clearShield()
        store.unlockedUntil = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        analytics.track("emergency_pass_used", properties: [
            "remaining": store.emergencyPassesRemaining
        ])
        return true
    }
}

/// The only supported way to obtain a `ScreenTimeService`.
///
/// Never name `FamilyControlsScreenTimeService` directly from a view or coordinator — on
/// Simulator and in un-entitled builds it must degrade to the mock rather than trap.
public enum ScreenTimeServiceFactory {
    public static func make(
        store: AppGroupStore = .shared,
        analytics: AnalyticsService = NoopAnalytics()
    ) -> ScreenTimeService {
        guard ScreenTimeAvailability.isSupported else {
            return MockScreenTimeService(store: store)
        }
        return FamilyControlsScreenTimeService(store: store, analytics: analytics)
    }
}

#if canImport(FamilyControls)
public extension DeviceActivityName {
    static let daily = DeviceActivityName("iqralock.daily")
    static let emergencyReshield = DeviceActivityName("iqralock.emergency")
    static let debugShort = DeviceActivityName("iqralock.debugShort")
}
#endif

/// Test / onboarding mock — no FamilyControls dependency.
public final class MockScreenTimeService: ScreenTimeService, @unchecked Sendable {
    public var authStatus: ScreenTimeAuthStatus = .notDetermined
    public var selectedAppCount: Int = 0
    public var isShielded: Bool = true
    private let store: AppGroupStore

    public init(store: AppGroupStore = AppGroupStore(suiteName: "mock.iqralock")) {
        self.store = store
        store.emergencyPassesRemaining = 3
    }

    public func requestAuthorization() async throws {
        authStatus = .approved
    }

    public func persistSelectionCount(_ count: Int) {
        selectedAppCount = count
        store.selectedAppsCount = count
    }

    public func applyShield() {
        isShielded = true
        store.isLockedNow = true
    }

    public func clearShield() {
        isShielded = false
        store.isLockedNow = false
    }

    public func scheduleMidnightReset() {}
    public func scheduleReshield(at date: Date) {}

    public func consumeEmergencyPass(durationMinutes: Int = 15) -> Bool {
        guard store.emergencyPassesRemaining > 0 else { return false }
        store.emergencyPassesRemaining -= 1
        clearShield()
        return true
    }
}
