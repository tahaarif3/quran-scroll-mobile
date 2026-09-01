import XCTest
@testable import IqraLockKit

final class PrayerCityCatalogTests: XCTestCase {
    func testSearchFindsCityByName() {
        let results = PrayerCityCatalog.search("Athens")
        XCTAssertTrue(results.contains { $0.id == "athens-ga" })
    }

    func testCitySetsCoordinatesOnProfile() {
        let profile = UserProfile()
        guard let city = PrayerCityCatalog.city(id: "makkah-sa") else {
            return XCTFail("missing city")
        }
        profile.applyPrayerCity(city)
        XCTAssertEqual(profile.prayerCityId, "makkah-sa")
        XCTAssertEqual(profile.prayerLatitude, city.latitude, accuracy: 0.001)
        XCTAssertNotNil(profile.prayerCoordinates)
    }

    func testNearestCityFromLegacyCoordinates() {
        let nearest = PrayerCityCatalog.nearestCity(latitude: 33.95, longitude: -83.37)
        XCTAssertEqual(nearest?.id, "athens-ga")
    }
}
