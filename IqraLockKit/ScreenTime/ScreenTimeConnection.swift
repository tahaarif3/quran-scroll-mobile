import Foundation

/// How far the user actually got through Screen Time setup.
///
/// Two independent things have to be true before a single app can be blocked: iOS has to have
/// granted Family Controls authorization, and the user has to have picked at least one app. They
/// are asked for in two separate onboarding steps, so declining or skipping either one leaves an
/// app that looks configured, says it is locking things, and shields nothing. That failure is
/// silent — which is why it needs a name.
///
/// Every surface that reports or repairs setup reads this instead of testing the two conditions
/// itself, so none of them can disagree about what "connected" means.
public enum ScreenTimeConnectionState: Equatable, Sendable {
    /// Authorized, with a selection. The shield can actually be applied.
    case connected
    /// Authorized, but nothing chosen — usually the picker step was skipped.
    case noAppsChosen
    /// The system prompt was never answered.
    case notConnected
    /// Answered no. iOS does not re-present its prompt for a denied request on every version, so
    /// this state has to be able to fall back to Settings.
    case declined
    /// Simulator, or a build without the family-controls entitlement. Nothing is wrong and
    /// nothing can be fixed from inside the app.
    case unsupported

    public var canBlockApps: Bool { self == .connected }

    /// Whether to ask the user to finish. `unsupported` is excluded deliberately — there is no
    /// action they could take, so a reminder would only be noise.
    public var needsAttention: Bool {
        switch self {
        case .noAppsChosen, .notConnected, .declined: return true
        case .connected, .unsupported: return false
        }
    }

    /// One line, honest about which half is missing.
    public var summary: String {
        switch self {
        case .connected: return "Connected"
        case .noAppsChosen: return "No apps chosen — nothing is being locked"
        case .notConnected: return "Not connected — nothing is being locked"
        case .declined: return "Access declined — nothing is being locked"
        case .unsupported: return "Not available on this device"
        }
    }
}

public enum ScreenTimeConnection {
    /// Reads authorization from the system and the selection from the App Group, in that order:
    /// a selection saved before authorization was revoked is worth nothing, so authorization
    /// decides first.
    public static func state(
        screenTime: ScreenTimeService,
        store: AppGroupStore = .shared
    ) -> ScreenTimeConnectionState {
        guard ScreenTimeAvailability.isSupported else { return .unsupported }
        switch screenTime.authStatus {
        case .denied:
            return .declined
        case .notDetermined:
            return .notConnected
        case .approved:
            // The count, not `selectedAppsData` — same signal `ShieldCoordinator` gates on, so
            // "connected" here and "will actually shield" there cannot diverge.
            return store.selectedAppsCount > 0 ? .connected : .noAppsChosen
        }
    }
}
