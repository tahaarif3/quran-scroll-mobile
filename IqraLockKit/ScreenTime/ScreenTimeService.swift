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

    public var selectedAppCount: Int {
        // Tokens are opaque; count is persisted when the picker saves.
        if store.selectedAppsCount > 0 { return store.selectedAppsCount }
        guard let data = store.selectedAppsData,
              let decoded = try? JSONDecoder().decode(SelectedAppsPayload.self, from: data) else {
            return 0
        }
        return decoded.count
    }

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

    public func persistSelectionCount(_ count: Int) {
        store.selectedAppsCount = count
        let payload = SelectedAppsPayload(count: count)
        if store.selectedAppsData == nil {
            store.selectedAppsData = try? JSONEncoder().encode(payload)
        }
        analytics.track("apps_selected", properties: ["count": count])
    }

    public func applyShield() {
        store.ensureCurrentDay()
        store.isLockedNow = true
        store.unlockedUntil = nil
        #if canImport(FamilyControls)
        // Actual ApplicationTokens are stored by the app target via FamilyActivitySelection.
        // Extensions / kit apply using ManagedSettingsStore when selection is available in-app.
        #endif
    }

    public func clearShield() {
        store.isLockedNow = false
        #if canImport(FamilyControls)
        managedSettings?.shield.applications = nil
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

public struct SelectedAppsPayload: Codable, Equatable, Sendable {
    public var count: Int
    public init(count: Int) { self.count = count }
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
        store.selectedAppsData = try? JSONEncoder().encode(SelectedAppsPayload(count: count))
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

    public func consumeEmergencyPass(durationMinutes: Int = 15) -> Bool {
        guard store.emergencyPassesRemaining > 0 else { return false }
        store.emergencyPassesRemaining -= 1
        clearShield()
        return true
    }
}
