import Foundation
import StoreKit

public enum PurchaseError: LocalizedError, Equatable {
    case productUnavailable
    case cancelled
    case pending
    case unverified
    case unknown

    public var errorDescription: String? {
        switch self {
        case .productUnavailable:
            // Overwhelmingly the cause is App Store Connect configuration rather than anything
            // on the device, so the message points there without blaming the user.
            return "Subscriptions aren't available right now. Please try again shortly."
        case .cancelled:
            return nil // The user chose this; surfacing an error would be noise.
        case .pending:
            return "Your purchase is awaiting approval. Pro unlocks once it's confirmed."
        case .unverified:
            return "That purchase couldn't be verified with the App Store."
        case .unknown:
            return "Something went wrong completing your purchase."
        }
    }
}

/// Real subscriptions via StoreKit 2.
///
/// One entitlement (`hasPro`) backed by two products, so `Transaction.currentEntitlements` is
/// the whole of the entitlement logic — no receipt parsing and no server.
public final class StoreKitPurchaseService: PurchaseService, @unchecked Sendable {
    public enum ProductID {
        public static let annual = "com.tahaarif.iqralock.pro.annual"
        public static let weekly = "com.tahaarif.iqralock.pro.weekly"
        public static var all: [String] { [annual, weekly] }
    }

    private let lock = NSLock()
    private var storedHasPro = false
    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private let analytics: AnalyticsService

    public init(analytics: AnalyticsService = NoopAnalytics()) {
        self.analytics = analytics
        // Must run for the app's whole lifetime. Renewals, refunds, family-sharing changes and
        // purchases made on another device all arrive here and nowhere else — without it the
        // entitlement silently goes stale.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified = update else { continue }
                await self?.refreshEntitlements()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Entitlement

    public var hasPro: Bool {
        lock.lock(); defer { lock.unlock() }
        return storedHasPro
    }

    public var gate: EntitlementGate { EntitlementGate(hasPro: hasPro) }

    public func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    /// The single source of truth for Pro. StoreKit caches these, so it works offline.
    public func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            // A refunded or upgraded-away subscription still appears here; revocationDate is
            // what distinguishes it from a live one.
            if transaction.revocationDate == nil {
                active = true
            }
        }
        lock.lock(); storedHasPro = active; lock.unlock()
    }

    // MARK: - Products

    private func loadProducts() async {
        guard let fetched = try? await Product.products(for: ProductID.all), !fetched.isEmpty else {
            // Almost always means the Paid Apps Agreement isn't active or the product IDs don't
            // exist yet — StoreKit reports both as an empty list rather than an error.
            analytics.track("products_unavailable", properties: [:])
            return
        }
        lock.lock()
        products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        lock.unlock()
    }

    private func product(_ id: String) -> Product? {
        lock.lock(); defer { lock.unlock() }
        return products[id]
    }

    // MARK: - Purchase

    public func purchaseAnnual() async throws { try await purchase(ProductID.annual) }
    public func purchaseWeekly() async throws { try await purchase(ProductID.weekly) }

    private func purchase(_ id: String) async throws {
        if product(id) == nil { await loadProducts() }
        guard let product = product(id) else { throw PurchaseError.productUnavailable }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PurchaseError.unverified
            }
            // Unfinished transactions are re-delivered on every launch forever.
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled:
            throw PurchaseError.cancelled
        case .pending:
            // Ask to Buy, or a payment needing approval. Not a failure — Transaction.updates
            // delivers it if and when it is approved.
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Display

    /// Localised prices straight from StoreKit, so currency and formatting follow the user's
    /// storefront rather than hardcoded dollars. Falls back to the design's figures only while
    /// products haven't loaded.
    public var annualPriceLabel: String { product(ProductID.annual)?.displayPrice ?? "$29.99" }
    public var weeklyPriceLabel: String { product(ProductID.weekly)?.displayPrice ?? "$2.99" }

    public var annualMonthlyDerived: String {
        guard let annual = product(ProductID.annual) else { return "$2.50" }
        return formatted(annual.price / 12, like: annual) ?? "$2.50"
    }

    public var savingsPercent: Int {
        guard let annual = product(ProductID.annual),
              let weekly = product(ProductID.weekly) else { return 60 }
        let yearlyAtWeeklyRate = weekly.price * 52
        guard yearlyAtWeeklyRate > 0 else { return 60 }
        let saved = (yearlyAtWeeklyRate - annual.price) / yearlyAtWeeklyRate
        return max(0, Int((saved * 100 as NSDecimalNumber).doubleValue.rounded()))
    }

    public var offeringId: String { "storekit" }

    private func formatted(_ amount: Decimal, like product: Product) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        return formatter.string(from: amount as NSDecimalNumber)
    }
}
