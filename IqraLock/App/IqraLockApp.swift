import SwiftUI
import SwiftData
import IqraLockKit

@main
struct IqraLockApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onOpenURL { appModel.handle(url: $0) }
                .task {
                    appModel.bootstrap()
                }
        }
        .modelContainer(for: [
            UserProfile.self,
            DailyRecord.self,
            ReadingSession.self,
            Bookmark.self,
            ReadingPosition.self
        ])
    }
}

@Observable
final class AppModel {
    var hasCompletedOnboarding: Bool
    var showReader: Bool = false
    var pendingDeepLink: URL?

    let analytics: AnalyticsService
    let purchases: PurchaseService
    let screenTime: ScreenTimeService
    let store: AppGroupStore
    let notifications: NotificationScheduling

    /// The one shield/unlock pair for the whole app. Views must resolve these from here rather
    /// than constructing their own — a locally-built coordinator reaches the real FamilyControls
    /// service regardless of what was injected, and mutates shield state out of band.
    let shield: ShieldCoordinator
    let unlock: UnlockCoordinator

    private let onboardingFlagKey = "iqralock.onboarding.completed"

    init(
        analytics: AnalyticsService = NoopAnalytics(),
        purchases: PurchaseService = MockPurchaseService(),
        screenTime: ScreenTimeService? = nil,
        store: AppGroupStore = .shared,
        notifications: NotificationScheduling = LocalNotificationScheduler()
    ) {
        let resolvedScreenTime = screenTime ?? ScreenTimeServiceFactory.make(
            store: store,
            analytics: analytics
        )
        self.analytics = analytics
        self.purchases = purchases
        self.screenTime = resolvedScreenTime
        self.store = store
        self.notifications = notifications
        let resolvedShield = ShieldCoordinator(store: store, screenTime: resolvedScreenTime)
        self.shield = resolvedShield
        self.unlock = UnlockCoordinator(
            store: store,
            shield: resolvedShield,
            analytics: analytics,
            notifications: notifications
        )
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingFlagKey)
    }

    func bootstrap() {
        store.ensureCurrentDay()
        store.resetEmergencyPassesIfNeeded()
        shield.reevaluate()
        if let pending = store.pendingDeepLink, let url = URL(string: pending) {
            store.pendingDeepLink = nil
            handle(url: url)
        }
        if UserDefaults(suiteName: AppGroupID.identifier)?.bool(forKey: "pending_shield_shown") == true {
            UserDefaults(suiteName: AppGroupID.identifier)?.set(false, forKey: "pending_shield_shown")
            analytics.track("shield_shown", properties: [:])
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingFlagKey)
    }

    #if DEBUG
    /// Return the app to a genuine first-run state without reinstalling.
    ///
    /// State lives in three places and all three must go, or onboarding either doesn't reappear
    /// or reappears on top of stale data: the completion flag in `UserDefaults.standard`, the
    /// SwiftData store, and the App Group shared with the extensions.
    func resetToFirstRun(modelContext: ModelContext) {
        screenTime.clearShield()

        UserDefaults.standard.removeObject(forKey: onboardingFlagKey)
        store.resetAllForDebug()

        // Written out rather than looped: `delete(model:)` is generic over `PersistentModel`,
        // so a heterogeneous array of metatypes will not satisfy it.
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: DailyRecord.self)
        try? modelContext.delete(model: ReadingSession.self)
        try? modelContext.delete(model: Bookmark.self)
        try? modelContext.delete(model: ReadingPosition.self)
        try? modelContext.save()

        showReader = false
        pendingDeepLink = nil
        hasCompletedOnboarding = false
    }
    #endif

    func handle(url: URL) {
        pendingDeepLink = url
        if url.host == "read" || url.path.contains("read") {
            showReader = true
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.easeOut(duration: 0.28), value: appModel.hasCompletedOnboarding)
    }
}
