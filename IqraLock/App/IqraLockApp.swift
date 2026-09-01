import SwiftUI
import SwiftData
import IqraLockKit

@main
struct IqraLockApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = AppModel()

    init() {
        // Before any view is built, so no code path can observe an unregistered font.
        IQFontRegistrar.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onOpenURL { appModel.handle(url: $0) }
                // Also on foreground, not just launch. The window only refills while the app
                // runs, and a user reading from the shield may go a long time without opening
                // it — which is the entire point of putting the ayah there.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    appModel.store.ensureCurrentDay()
                    Task.detached(priority: .utility) { [store = appModel.store] in
                        ShieldAyahProvider.refreshCache(store: store)
                    }
                }
                .task {
                    appModel.bootstrap()
                    // Surviving a few seconds of real running is the signal that the launch
                    // actually worked — long enough to be past view construction, the first
                    // layout pass and the initial shield evaluation.
                    try? await Task.sleep(for: .seconds(4))
                    appModel.markLaunchHealthy()
                }
        }
        .modelContainer(for: [
            UserProfile.self,
            DailyRecord.self,
            ReadingSession.self,
            Bookmark.self,
            ReadingPosition.self,
            PrayerLog.self
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
        // Temporarily mocked for testing. StoreKitPurchaseService is finished and wired — swap
        // this line back once the App Store Connect products exist and the Paid Apps Agreement
        // is active, otherwise every purchase throws "Subscriptions aren't available" and Pro,
        // which gates blocking, can never be reached on a test build.
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

    /// How far Screen Time setup actually got. Read live rather than cached: authorization can
    /// be revoked in Settings while the app is backgrounded, and a stale "connected" would keep
    /// the app claiming to shield apps it can no longer touch.
    var screenTimeConnection: ScreenTimeConnectionState {
        ScreenTimeConnection.state(screenTime: screenTime, store: store)
    }

    /// Number of consecutive launches that died before the app was healthy, after which the
    /// shield is lifted. Two rather than one: a single crash can be a one-off, but a user whose
    /// apps are blocked by an app that will not open has no way out except deleting it.
    private static let launchFailureThreshold = 2

    /// Lifts the shield when the app cannot survive its own launch.
    ///
    /// Blocking apps is only defensible while the user can reach the thing that unblocks them.
    /// A crash on launch otherwise strands them with their apps locked and no recourse — which
    /// is exactly what happened when an unregistered tab-bar font aborted the app on every
    /// start. Runs before anything else touches the shield.
    private func recoverFromFailedLaunchesIfNeeded() {
        if store.launchInProgress {
            store.consecutiveLaunchFailures += 1
        } else {
            store.consecutiveLaunchFailures = 0
        }
        store.launchInProgress = true

        guard store.consecutiveLaunchFailures >= Self.launchFailureThreshold else { return }
        analytics.track("shield_released_after_failed_launches", properties: [
            "failures": store.consecutiveLaunchFailures
        ])
        screenTime.clearShield()
        store.unlockedUntil = Date().addingTimeInterval(60 * 60)
        store.consecutiveLaunchFailures = 0
    }

    /// Called once the app has run long enough to be considered healthy. Deliberately not on
    /// `onAppear`: the font crash happened in the layout pass *after* onAppear had fired, so
    /// clearing the marker there would have recorded a successful launch moments before dying.
    func markLaunchHealthy() {
        store.launchInProgress = false
        store.consecutiveLaunchFailures = 0
    }

    func bootstrap() {
        #if DEBUG
        IQFontAudit.verify()
        #endif
        recoverFromFailedLaunchesIfNeeded()
        // Loads prices and re-reads the entitlement. Without it the paywall shows fallback
        // prices and a subscriber who reinstalled would look unsubscribed until they restored.
        Task { await purchases.refresh() }
        // Refill the shield's ayah window. The extension cannot read the database itself, so
        // this is the only thing that keeps an ayah on the lock screen.
        Task.detached(priority: .utility) { [store] in
            ShieldAyahProvider.refreshCache(store: store)
        }
        store.ensureCurrentDay()
        store.resetBathroomBreaksIfNeeded()
        shield.reevaluate()
        notifications.scheduleStreakAtRiskIfNeeded(goalMet: store.goalMetToday)
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
        try? modelContext.delete(model: PrayerLog.self)
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

    func syncDailyProgress(context: ModelContext, minutesDelta: Int = 0) {
        DailyProgressSync.upsertToday(
            context: context,
            store: store,
            minutesDelta: minutesDelta
        )
        notifications.scheduleStreakAtRiskIfNeeded(goalMet: store.goalMetToday)
    }

    func schedulePrayerNotificationsIfEnabled(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first,
              profile.prayerNotificationsEnabled,
              let coords = profile.prayerCoordinates else {
            notifications.cancelPrayerNotifications()
            return
        }
        notifications.schedulePrayerNotifications(
            latitude: coords.latitude,
            longitude: coords.longitude
        )
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
