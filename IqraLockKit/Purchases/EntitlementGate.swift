import Foundation

public struct EntitlementGate: Equatable, Sendable {
    public var hasPro: Bool

    public init(hasPro: Bool) {
        self.hasPro = hasPro
    }

    // Product decision: reader stays free; pro gates blocking + stats extras.
    public var canReadQuran: Bool { true }
    public var canBlockApps: Bool { hasPro }
    public var canSeeStats: Bool { hasPro }
    public var maxTranslations: Int { hasPro ? 20 : 1 }
    public var maxEmergencyPasses: Int { hasPro ? 5 : 2 }
    public var canUseReaderThemes: Bool { hasPro }
    public var canUseWidgets: Bool { hasPro }
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
