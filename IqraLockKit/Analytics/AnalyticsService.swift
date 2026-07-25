import Foundation

public protocol AnalyticsService: AnyObject, Sendable {
    func track(_ event: String, properties: [String: Any])
}

public final class NoopAnalytics: AnalyticsService, @unchecked Sendable {
    public init() {}
    public func track(_ event: String, properties: [String: Any] = [:]) {}
}

/// PostHog-ready shim. Replace body with PostHogSDK calls when the package is added.
public final class PostHogAnalytics: AnalyticsService, @unchecked Sendable {
    private let apiKey: String
    public init(apiKey: String) { self.apiKey = apiKey }
    public func track(_ event: String, properties: [String: Any] = [:]) {
        #if DEBUG
        print("[Analytics]", event, properties)
        #endif
        // PostHogSDK.shared.capture(event, properties: properties)
    }
}
