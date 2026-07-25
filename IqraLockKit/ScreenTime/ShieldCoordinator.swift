import Foundation

#if canImport(ManagedSettings)
import ManagedSettings
import FamilyControls
#endif

/// Single source of truth for lock/unlock, mirrored into the App Group.
public final class ShieldCoordinator: @unchecked Sendable {
    public static let shared = ShieldCoordinator()

    private let store: AppGroupStore
    private let screenTime: ScreenTimeService

    public init(store: AppGroupStore = .shared, screenTime: ScreenTimeService? = nil) {
        self.store = store
        self.screenTime = screenTime ?? FamilyControlsScreenTimeService(store: store)
    }

    public var isLockedNow: Bool { store.isLockedNow }

    public func reevaluate(now: Date = Date()) {
        store.ensureCurrentDay(now: now)
        if let until = store.unlockedUntil, until > now {
            store.isLockedNow = false
            screenTime.clearShield()
            return
        }
        if store.goalMetToday {
            store.isLockedNow = false
            screenTime.clearShield()
            return
        }
        if store.selectedAppsData != nil {
            store.isLockedNow = true
            screenTime.applyShield()
        }
    }

    public func lockSelectedApps() {
        store.isLockedNow = true
        screenTime.applyShield()
    }

    public func unlockForRestOfDay(now: Date = Date(), calendar: Calendar = .current) {
        store.isLockedNow = false
        let start = calendar.startOfDay(for: now)
        store.unlockedUntil = calendar.date(byAdding: .day, value: 1, to: start)
        screenTime.clearShield()
    }
}
