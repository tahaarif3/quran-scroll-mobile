import XCTest
@testable import IqraLockKit

final class ScreenTimeConnectionTests: XCTestCase {
    private func makeStore() -> AppGroupStore {
        AppGroupStore(suiteName: "test.screentime.connection.\(UUID().uuidString)")
    }

    func testApprovedWithoutSelectionIsNotConnected() {
        let store = makeStore()
        let screenTime = MockScreenTimeService(store: store)
        screenTime.authStatus = .approved

        XCTAssertEqual(
            ScreenTimeConnection.state(screenTime: screenTime, store: store),
            .noAppsChosen
        )
    }

    func testOrphanedSelectionCountIsNotConnected() {
        let store = makeStore()
        store.selectedAppsCount = 3
        store.selectedAppsData = nil
        let screenTime = MockScreenTimeService(store: store)
        screenTime.authStatus = .approved

        XCTAssertEqual(
            ScreenTimeConnection.state(screenTime: screenTime, store: store),
            .selectionUnavailable
        )
        XCTAssertFalse(store.hasPersistedAppSelection)
        XCTAssertTrue(ScreenTimeConnection.state(screenTime: screenTime, store: store).needsAttention)
        XCTAssertFalse(ScreenTimeConnection.state(screenTime: screenTime, store: store).canBlockApps)
    }

    func testPersistedSelectionBlobMarksConnectedWhenTokensCannotBeDecodedHere() {
        let store = makeStore()
        store.selectedAppsCount = 2
        store.selectedAppsData = Data("selection".utf8)
        let screenTime = MockScreenTimeService(store: store)
        screenTime.authStatus = .approved

        #if canImport(FamilyControls)
        // On Apple platforms the blob must decode into real tokens. Junk data is unavailable.
        XCTAssertEqual(
            ScreenTimeConnection.state(screenTime: screenTime, store: store),
            .selectionUnavailable
        )
        #else
        XCTAssertEqual(
            ScreenTimeConnection.state(screenTime: screenTime, store: store),
            .connected
        )
        #endif
    }

    func testHomeReportsFailedShieldOnlyWhenALockWasExpected() {
        XCTAssertFalse(
            HomeShieldPresentation.reportsFailedShield(
                isLockedNow: false,
                selectedAppsCount: 0,
                hasPersistedAppSelection: false
            ),
            "Never-finished Screen Time setup is not a failed re-lock"
        )
        XCTAssertFalse(
            HomeShieldPresentation.reportsFailedShield(
                isLockedNow: true,
                selectedAppsCount: 4,
                hasPersistedAppSelection: true
            )
        )
        XCTAssertTrue(
            HomeShieldPresentation.reportsFailedShield(
                isLockedNow: false,
                selectedAppsCount: 4,
                hasPersistedAppSelection: false
            )
        )
        XCTAssertTrue(
            HomeShieldPresentation.reportsFailedShield(
                isLockedNow: false,
                selectedAppsCount: 0,
                hasPersistedAppSelection: true
            )
        )
    }

    func testFocusDeepLinkTargetsAreRecognized() {
        let focus = URL(string: "iqralock://focus")!
        XCTAssertEqual(focus.host, "focus")
        let read = URL(string: "iqralock://read")!
        XCTAssertEqual(read.host, "read")
    }
}
