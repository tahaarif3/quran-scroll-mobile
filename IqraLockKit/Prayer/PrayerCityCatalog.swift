import Foundation

public struct PrayerCity: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let region: String
    public let latitude: Double
    public let longitude: Double

    public var label: String { "\(name), \(region)" }

    public init(id: String, name: String, region: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Offline city list for prayer-time calculation — no coordinates typed by hand.
public enum PrayerCityCatalog {
    public static let defaultCityID = "atlanta-ga"

    public static let all: [PrayerCity] = [
        PrayerCity(id: "atlanta-ga", name: "Atlanta", region: "GA", latitude: 33.749, longitude: -84.388),
        PrayerCity(id: "athens-ga", name: "Athens", region: "GA", latitude: 33.951, longitude: -83.357),
        PrayerCity(id: "new-york-ny", name: "New York", region: "NY", latitude: 40.713, longitude: -74.006),
        PrayerCity(id: "chicago-il", name: "Chicago", region: "IL", latitude: 41.878, longitude: -87.630),
        PrayerCity(id: "houston-tx", name: "Houston", region: "TX", latitude: 29.760, longitude: -95.370),
        PrayerCity(id: "dallas-tx", name: "Dallas", region: "TX", latitude: 32.777, longitude: -96.797),
        PrayerCity(id: "los-angeles-ca", name: "Los Angeles", region: "CA", latitude: 34.052, longitude: -118.244),
        PrayerCity(id: "san-francisco-ca", name: "San Francisco", region: "CA", latitude: 37.774, longitude: -122.419),
        PrayerCity(id: "seattle-wa", name: "Seattle", region: "WA", latitude: 47.606, longitude: -122.332),
        PrayerCity(id: "miami-fl", name: "Miami", region: "FL", latitude: 25.762, longitude: -80.192),
        PrayerCity(id: "orlando-fl", name: "Orlando", region: "FL", latitude: 28.538, longitude: -81.379),
        PrayerCity(id: "washington-dc", name: "Washington", region: "DC", latitude: 38.907, longitude: -77.037),
        PrayerCity(id: "philadelphia-pa", name: "Philadelphia", region: "PA", latitude: 39.953, longitude: -75.164),
        PrayerCity(id: "boston-ma", name: "Boston", region: "MA", latitude: 42.360, longitude: -71.059),
        PrayerCity(id: "detroit-mi", name: "Detroit", region: "MI", latitude: 42.331, longitude: -83.046),
        PrayerCity(id: "minneapolis-mn", name: "Minneapolis", region: "MN", latitude: 44.978, longitude: -93.265),
        PrayerCity(id: "denver-co", name: "Denver", region: "CO", latitude: 39.739, longitude: -104.990),
        PrayerCity(id: "phoenix-az", name: "Phoenix", region: "AZ", latitude: 33.448, longitude: -112.074),
        PrayerCity(id: "london-uk", name: "London", region: "UK", latitude: 51.507, longitude: -0.128),
        PrayerCity(id: "birmingham-uk", name: "Birmingham", region: "UK", latitude: 52.486, longitude: -1.890),
        PrayerCity(id: "toronto-ca", name: "Toronto", region: "Canada", latitude: 43.653, longitude: -79.383),
        PrayerCity(id: "makkah-sa", name: "Makkah", region: "Saudi Arabia", latitude: 21.422, longitude: 39.826),
        PrayerCity(id: "madinah-sa", name: "Madinah", region: "Saudi Arabia", latitude: 24.468, longitude: 39.614),
        PrayerCity(id: "riyadh-sa", name: "Riyadh", region: "Saudi Arabia", latitude: 24.713, longitude: 46.675),
        PrayerCity(id: "jeddah-sa", name: "Jeddah", region: "Saudi Arabia", latitude: 21.543, longitude: 39.173),
        PrayerCity(id: "dubai-ae", name: "Dubai", region: "UAE", latitude: 25.204, longitude: 55.271),
        PrayerCity(id: "cairo-eg", name: "Cairo", region: "Egypt", latitude: 30.044, longitude: 31.235),
        PrayerCity(id: "istanbul-tr", name: "Istanbul", region: "Türkiye", latitude: 41.008, longitude: 28.978),
        PrayerCity(id: "karachi-pk", name: "Karachi", region: "Pakistan", latitude: 24.861, longitude: 67.010),
        PrayerCity(id: "lahore-pk", name: "Lahore", region: "Pakistan", latitude: 31.520, longitude: 74.359),
        PrayerCity(id: "delhi-in", name: "Delhi", region: "India", latitude: 28.614, longitude: 77.209),
        PrayerCity(id: "mumbai-in", name: "Mumbai", region: "India", latitude: 19.076, longitude: 72.878),
        PrayerCity(id: "jakarta-id", name: "Jakarta", region: "Indonesia", latitude: -6.208, longitude: 106.845),
        PrayerCity(id: "kuala-lumpur-my", name: "Kuala Lumpur", region: "Malaysia", latitude: 3.139, longitude: 101.687),
        PrayerCity(id: "singapore-sg", name: "Singapore", region: "Singapore", latitude: 1.352, longitude: 103.820),
        PrayerCity(id: "sydney-au", name: "Sydney", region: "Australia", latitude: -33.869, longitude: 151.209),
    ].sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    public static func city(id: String) -> PrayerCity? {
        all.first { $0.id == id }
    }

    public static func search(_ query: String) -> [PrayerCity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.region.localizedCaseInsensitiveContains(trimmed)
                || $0.label.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Picks the nearest bundled city to legacy coordinate-only profiles.
    public static func nearestCity(latitude: Double, longitude: Double) -> PrayerCity? {
        guard latitude != 0 || longitude != 0 else { return nil }
        return all.min { lhs, rhs in
            distanceSquared(lat: latitude, lon: longitude, city: lhs)
                < distanceSquared(lat: latitude, lon: longitude, city: rhs)
        }
    }

    private static func distanceSquared(lat: Double, lon: Double, city: PrayerCity) -> Double {
        let dLat = lat - city.latitude
        let dLon = lon - city.longitude
        return dLat * dLat + dLon * dLon
    }
}

public extension UserProfile {
    var selectedPrayerCity: PrayerCity? {
        if !prayerCityId.isEmpty, let city = PrayerCityCatalog.city(id: prayerCityId) {
            return city
        }
        return PrayerCityCatalog.nearestCity(latitude: prayerLatitude, longitude: prayerLongitude)
    }

    var prayerCoordinates: (latitude: Double, longitude: Double)? {
        if let city = selectedPrayerCity {
            return (city.latitude, city.longitude)
        }
        if prayerLatitude != 0 || prayerLongitude != 0 {
            return (prayerLatitude, prayerLongitude)
        }
        return nil
    }

    func applyPrayerCity(_ city: PrayerCity) {
        prayerCityId = city.id
        prayerLatitude = city.latitude
        prayerLongitude = city.longitude
    }
}
