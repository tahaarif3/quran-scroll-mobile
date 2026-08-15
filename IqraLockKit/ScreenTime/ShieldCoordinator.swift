import Foundation

#if canImport(ManagedSettings)
import ManagedSettings
import FamilyControls
#endif

/// Single source of truth for lock/unlock, mirrored into the App Group.
public final class ShieldCoordinator: @unchecked Sendable {
    private let store: AppGroupStore
    private let screenTime: ScreenTimeService

    public init(store: AppGroupStore = .shared, screenTime: ScreenTimeService? = nil) {
        self.store = store
        self.screenTime = screenTime ?? ScreenTimeServiceFactory.make(store: store)
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
        // Gated on the count, not on `selectedAppsData`. The mock picker used in Simulator
        // records a count without any real tokens, and the count is also what survives when a
        // selection is cleared, so it is the reliable signal for "the user chose to shield".
        if store.selectedAppsCount > 0 {
            store.isLockedNow = true
            screenTime.applyShield()
        }
    }

    /// Grants the unlock window an ayah has just earned, lifts the shield, and books its return.
    ///
    /// Reading an ayah in the app used to credit the goal but buy no time, while reading the
    /// same ayah off the shield bought thirty minutes — the same act worth different amounts
    /// depending on where it happened. Every counted ayah now earns the window.
    public func grantAyahWindow(now: Date = Date()) {
        store.grantAyahWindow(now: now)
        screenTime.clearShield()
        if let until = store.unlockedUntil {
            screenTime.scheduleReshield(at: until)
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
