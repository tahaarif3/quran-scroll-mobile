import XCTest
@testable import IqraLockKit

/// Regression cover for the post-paywall launch crash.
///
/// `ReaderView` held `private let unlock = UnlockCoordinator()` as a stored property. `TabView`
/// builds every tab's view value up front, so that ran during view-tree construction the instant
/// the root swapped after onboarding, cascading through defaulted initializers into
/// `ManagedSettingsStore()` — which traps on Simulator and without the Family Controls
/// entitlement. `#if canImport(FamilyControls)` only gates compilation, not runtime.
final class ScreenTimeServiceFactoryTests: XCTestCase {
    private func makeStore() -> AppGroupStore {
        AppGroupStore(suiteName: "test.iqralock.factory")
    }

    func testFactoryReturnsMockWhereFamilyControlsCannotRun() {
        let service = ScreenTimeServiceFactory.make(store: makeStore())

        if ScreenTimeAvailability.isSupported {
            XCTAssertTrue(service is FamilyControlsScreenTimeService)
        } else {
            XCTAssertTrue(
                service is MockScreenTimeService,
                "Unsupported environments must degrade to the mock, never construct ManagedSettings"
            )
        }
    }

    func testFamilyControlsIsNeverConsideredSupportedOnSimulator() throws {
        #if targetEnvironment(simulator)
        XCTAssertFalse(
            ScreenTimeAvailability.isSupported,
            "FamilyControls compiles on Simulator but traps at runtime"
        )
        #else
        throw XCTSkip("Simulator-only assertion")
        #endif
    }

    /// The crash was a construction-time trap, so merely building the graph must be safe.
    func testConstructingCoordinatorGraphDoesNotTrap() {
        let store = makeStore()
        let unlock = UnlockCoordinator(
            store: store,
            shield: ShieldCoordinator(store: store),
            notifications: NotificationTestDouble()
        )
        XCTAssertNotNil(unlock)
    }

    /// Shield operations must no-op rather than trap when the runtime is unavailable.
    func testShieldOperationsAreSafeWhenUnsupported() {
        let store = makeStore()
        let coordinator = ShieldCoordinator(store: store)

        coordinator.lockSelectedApps()
        XCTAssertTrue(store.isLockedNow)

        coordinator.unlockForRestOfDay()
        XCTAssertFalse(store.isLockedNow)
    }
}

