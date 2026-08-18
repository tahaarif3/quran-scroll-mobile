import DeviceActivity
import ManagedSettings
import IqraLockKit
import UserNotifications

/// Primary "Read now" cannot launch the host app — posts a deep-link notification, then `.close`.
/// Emergency pass clears the ManagedSettings shield for a short window.
final class ShieldActionExtension: ShieldActionDelegate {
    private let store = AppGroupStore.shared

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        perform(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        perform(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        perform(action: action, completionHandler: completionHandler)
    }

    private func perform(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // "Open <app>" — credit the ayah, then spend it and get out of the way.
            completionHandler(readAyah(thenContinue: true))
        case .secondaryButtonPressed:
            // "Read another ayah" — credit it and stay put, so the next one is served.
            completionHandler(readAyah(thenContinue: false))
        @unknown default:
            completionHandler(.close)
        }
    }

    /// Credits one ayah, and either spends it on access or banks it and serves another.
    ///
    /// Both buttons read, both earn the window, and both unblock the apps — the time is real
    /// either way. The only difference is the response: `.close` steps aside so the app can be
    /// opened, `.defer` keeps the shield on screen so the next ayah can be read straight away.
    ///
    /// `.defer` was briefly used for both, which is what made "add 30 more minutes" look dead —
    /// the shield sat there after the apps beneath it had already been unblocked. Then both were
    /// `.close`, which made "Read another ayah" look dead instead, because asking for another
    /// ayah dismissed the only thing showing them. One each is the arrangement that matches what
    /// the two buttons actually say.
    private func readAyah(thenContinue: Bool) -> ShieldActionResponse {
        let now = Date()

        // A long ayah is served in waqf-bounded pieces. Every piece earns a window, because
        // every piece is a real act of reading — but the ayah only counts toward the goal and
        // only moves the cursor when its final piece is read.
        let segmentCount = ShieldAyahProvider.segmentCount(for: store)
        let isFinalSegment = store.shieldSegmentIndex >= segmentCount - 1

        guard isFinalSegment else {
            if let last = store.lastAyahReadAt,
               now.timeIntervalSince(last) < AppGroupStore.minimumAyahInterval {
                store.ayahRejectedAt = now
                return .defer
            }
            store.lastAyahReadAt = now
            store.ayahRejectedAt = nil
            store.shieldSegmentIndex += 1
            store.grantAyahWindow(now: now)
            clearShield()
            scheduleReshield(at: store.unlockedUntil ?? now)
            return thenContinue ? .close : .defer
        }

        let record = store.recordAyah(now: now)

        guard record.counted else {
            // Arrived inside the minimum interval. Deferring re-presents the shield; the flag
            // lets the configuration explain why nothing happened rather than looking broken.
            store.ayahRejectedAt = now
            return .defer
        }

        // The ayah just shown was the one at the cursor, so move past it. This is what makes the
        // khatm number honest: it counts ayahs actually passed through, in order.
        store.advanceKhatmCursor()
        store.shieldSegmentIndex = 0

        // Finishing the day's goal is worth more than a single window.
        if record.goalMet {
            let calendar = Calendar.current
            store.isLockedNow = false
            store.unlockedUntil = calendar.date(
                byAdding: .day, value: 1, to: calendar.startOfDay(for: now)
            )
            clearShield()
            notify(title: "Apps unlocked", body: "You finished today's reading. Your apps are open until tomorrow.")
            return .close
        }

        store.grantAyahWindow(now: now)
        clearShield()
        scheduleReshield(at: store.unlockedUntil ?? now)
        return thenContinue ? .close : .defer
    }

    private func clearShield() {
        let managed = ManagedSettingsStore()
        managed.shield.applications = nil
        managed.shield.applicationCategories = nil
    }

    /// ManagedSettings has no expiry of its own — a lifted shield stays lifted until something
    /// puts it back. Without this the "30 minutes" would last until the user next opened
    /// IqraLock, which for someone avoiding the app is indefinitely.
    private func scheduleReshield(at date: Date) {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let end = calendar.dateComponents([.hour, .minute, .second], from: date)
        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: false
        )
        let center = DeviceActivityCenter()
        // See ScreenTimeService.scheduleReshield: restarting a live activity ends its interval,
        // and the end handler re-applies the shield.
        center.stopMonitoring([.emergencyReshield])
        try? center.startMonitoring(.emergencyReshield, during: schedule)
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.4, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "shield_unlocked", content: content, trigger: trigger)
        )
    }
}
