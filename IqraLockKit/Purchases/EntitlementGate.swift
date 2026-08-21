import Foundation

public struct EntitlementGate: Equatable, Sendable {
    public var hasPro: Bool

    public init(hasPro: Bool) {
        self.hasPro = hasPro
    }

    // Nothing is withheld. Every feature is available to everyone, subscribed or not, and
    // subscribing is support rather than access.
    //
    // This is not a stub — it is the product decision, and it makes the code match what the app
    // has always actually done. `canBlockApps` claimed to gate blocking while `ShieldCoordinator`
    // never consulted it, so blocking worked for everyone regardless; the gate's only real effect
    // was UI copy telling free users they were missing something they already had. Charging for
    // access the app grants anyway is the part worth not shipping.
    //
    // `hasPro` is kept because the subscription is real even when the entitlement is not — it
    // still says who is supporting the app, which the You screen shows.
    public var canReadQuran: Bool { true }
    public var canBlockApps: Bool { true }
    public var canSeeStats: Bool { true }
    public var maxTranslations: Int { 20 }
    public var maxEmergencyPasses: Int { 5 }
    public var canUseReaderThemes: Bool { true }
    public var canUseWidgets: Bool { true }
}

public protocol PurchaseService: AnyObject, Sendable {
    var hasPro: Bool { get }
    var gate: EntitlementGate { get }
    func refresh() async
    func purchaseAnnual() async throws
    func purchaseWeekly() async throws
    func restore() async throws
    var annualPriceLabel: String { get }
    var weeklyPriceLabel: String { get }
    var annualMonthlyDerived: String { get }
    var savingsPercent: Int { get }
    var offeringId: String { get }
}

public final class MockPurchaseService: PurchaseService, @unchecked Sendable {
    public private(set) var hasPro: Bool
    public var annualPriceLabel: String = "$29.99"
    public var weeklyPriceLabel: String = "$2.99"
    public var annualMonthlyDerived: String = "$2.50" // derived from annual/12 for SAVE pill math
    public var savingsPercent: Int = 60
    public var offeringId: String = "default"

    public init(hasPro: Bool = false) { self.hasPro = hasPro }
    public var gate: EntitlementGate { EntitlementGate(hasPro: hasPro) }
    public func refresh() async {}
    public func purchaseAnnual() async throws { hasPro = true }
    public func purchaseWeekly() async throws { hasPro = true }
    public func restore() async throws { hasPro = true }
}
