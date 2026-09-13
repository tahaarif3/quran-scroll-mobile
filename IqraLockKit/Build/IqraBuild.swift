import Foundation

/// Compile-time flavor. Internal TestFlight is a Release archive with `INTERNAL_TESTFLIGHT`
/// set, because `#if DEBUG` is compiled out of normal TestFlight uploads.
public enum IqraBuild {
    public static var showsInternalTools: Bool {
        #if DEBUG || INTERNAL_TESTFLIGHT
        true
        #else
        false
        #endif
    }

    public static var usesMockPurchases: Bool {
        #if DEBUG || INTERNAL_TESTFLIGHT
        true
        #else
        false
        #endif
    }
}

public enum LegalLinks {
    public static let privacy = URL(string: "https://iqralock.app/privacy")!
    public static let terms = URL(string: "https://iqralock.app/terms")!
}

public enum PurchaseServiceFactory {
    public static func make(analytics: AnalyticsService = NoopAnalytics()) -> PurchaseService {
        #if DEBUG || INTERNAL_TESTFLIGHT
        return MockPurchaseService()
        #else
        return StoreKitPurchaseService(analytics: analytics)
        #endif
    }
}
