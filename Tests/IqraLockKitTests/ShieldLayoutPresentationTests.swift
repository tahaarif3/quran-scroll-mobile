import XCTest
@testable import IqraLockKit

final class ShieldLayoutPresentationTests: XCTestCase {
    private let store = AppGroupStore(suiteName: "test.shield.layout.\(UUID().uuidString)")

    override func tearDown() {
        #if DEBUG
        store.resetAllForDebug()
        #endif
        super.tearDown()
    }

    private func sampleSegment() -> ShieldAyahProvider.Segmented {
        ShieldAyahProvider.Segmented(
            arabic: "بِسْمِ اللَّهِ",
            translation: "In the name of Allah",
            reference: "1:1",
            index: 0,
            count: 1
        )
    }

    func testBothLayoutShowsArabicAndTranslation() {
        let content = ShieldLayoutPresentation.make(
            mode: .arabicAndTranslation,
            segment: sampleSegment(),
            appName: "Instagram",
            store: store,
            recentlyRejected: false
        )
        XCTAssertEqual(content.title, "بِسْمِ اللَّهِ")
        XCTAssertTrue(content.subtitle.contains("In the name of Allah"))
        XCTAssertTrue(content.primaryButton.contains("Instagram"))
        XCTAssertEqual(content.secondaryButton, "Read another ayah")
    }

    func testArabicOnlyLayoutShowsReferenceSubtitle() {
        let content = ShieldLayoutPresentation.make(
            mode: .arabicOnly,
            segment: sampleSegment(),
            appName: "Instagram",
            store: store,
            recentlyRejected: false
        )
        XCTAssertEqual(content.title, "بِسْمِ اللَّهِ")
        XCTAssertEqual(content.subtitle, "1:1")
    }

    func testTranslationOnlyLayoutSwapsSlots() {
        let content = ShieldLayoutPresentation.make(
            mode: .translationOnly,
            segment: sampleSegment(),
            appName: "Instagram",
            store: store,
            recentlyRejected: false
        )
        XCTAssertEqual(content.title, "In the name of Allah")
        XCTAssertEqual(content.subtitle, "1:1")
    }

    func testNoneLayoutOpensReaderInApp() {
        store.dailyGoalAyahs = 30
        store.ayahsReadToday = 3
        let content = ShieldLayoutPresentation.make(
            mode: .none,
            segment: sampleSegment(),
            appName: "Instagram",
            store: store,
            recentlyRejected: false
        )
        XCTAssertEqual(content.primaryButton, "Read in IqraLock")
        XCTAssertNil(content.secondaryButton)
        XCTAssertTrue(content.subtitle.contains("3 of 30 ayahs today"))
    }

    func testShieldLayoutModePersistsInAppGroup() {
        store.shieldLayoutMode = .translationOnly
        XCTAssertEqual(store.shieldLayoutMode, .translationOnly)
    }

    func testAppGroupPrayerCityProvidesCoordinates() {
        let store = AppGroupStore(suiteName: "test.prayer.city.\(UUID().uuidString)")
        store.prayerCityId = "atlanta-ga"
        XCTAssertNotNil(store.prayerCoordinates)
        XCTAssertNotNil(PrayerCitySelection.coordinates(profile: nil, store: store))
    }
}
