import Foundation

public struct EntitlementGate: Equatable, Sendable {
    public var hasPro: Bool

    public init(hasPro: Bool) {
        self.hasPro = hasPro
    }

    // Pro exists; it just has nothing of its own yet.
    //
    // Every feature currently in the app ships to everyone, so every flag below ignores
    // `hasPro`. That is honesty about today rather than a permanent decision — this is the one
    // place a real Pro feature gets gated when there is one, and the only change needed is
    // returning `hasPro` from the flag that guards it.
    //
    // What was here before gated blocking and stats on `hasPro` while `ShieldCoordinator` never
    // consulted `canBlockApps` — blocking worked for everyone regardless, so the flags produced
    // nothing but copy telling free users they lacked what they already had. A gate that lies is
    // worse than no gate: it is the paywall users discover was never real.
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
