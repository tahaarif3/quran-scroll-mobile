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

/// Production service. FamilyControls APIs compile only when the entitlement is present;
/// methods are no-ops / mocked behavior when unavailable (Simulator / Linux syntax check).
public final class FamilyControlsScreenTimeService: ScreenTimeService, @unchecked Sendable {
    private let store: AppGroupStore
    private let analytics: AnalyticsService

    #if canImport(FamilyControls)
    private let managedSettings = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared
    #endif

    public init(store: AppGroupStore = .shared, analytics: AnalyticsService = NoopAnalytics()) {
        self.store = store
        self.analytics = analytics
    }

    public var authStatus: ScreenTimeAuthStatus {
        #if canImport(FamilyControls)
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
        managedSettings.shield.applications = nil
        #endif
    }

    public func scheduleMidnightReset() {
        #if canImport(FamilyControls)
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
