import Foundation

/// Title, subtitle, and button labels for the OS shield — shared by the extension and in-app preview.
public enum ShieldLayoutPresentation {
    public struct Content: Equatable, Sendable {
        public let title: String
        public let subtitle: String
        public let primaryButton: String
        public let secondaryButton: String?

        public init(
            title: String,
            subtitle: String,
            primaryButton: String,
            secondaryButton: String?
        ) {
            self.title = title
            self.subtitle = subtitle
            self.primaryButton = primaryButton
            self.secondaryButton = secondaryButton
        }
    }

    public static func make(
        mode: ShieldLayoutMode,
        segment: ShieldAyahProvider.Segmented?,
        appName: String,
        store: AppGroupStore,
        recentlyRejected: Bool
    ) -> Content {
        if recentlyRejected {
            return Content(
                title: rejectionTitle(mode: mode, segment: segment),
                subtitle: "Take a moment with it, then continue",
                primaryButton: primaryButtonLabel(mode: mode, appName: appName, store: store),
                secondaryButton: secondaryButtonLabel(mode: mode, segment: segment)
            )
        }

        switch mode {
        case .none:
            return noneContent(segment: segment, appName: appName, store: store)
        case .arabicAndTranslation:
            return bothContent(segment: segment, appName: appName, store: store)
        case .arabicOnly:
            return arabicOnlyContent(segment: segment, appName: appName, store: store)
        case .translationOnly:
            return translationOnlyContent(segment: segment, appName: appName, store: store)
        }
    }

    private static func noneContent(
        segment: ShieldAyahProvider.Segmented?,
        appName: String,
        store: AppGroupStore
    ) -> Content {
        let progress = "\(store.totalAyahsToday) of \(store.dailyGoalAyahs) ayahs today"
        let reference = segment?.reference ?? "Today's ayah is waiting in IqraLock"
        return Content(
            title: "Read to unlock \(appName)",
            subtitle: "\(progress)\n\(reference)",
            primaryButton: "Read in IqraLock",
            secondaryButton: nil
        )
    }

    private static func bothContent(
        segment: ShieldAyahProvider.Segmented?,
        appName: String,
        store: AppGroupStore
    ) -> Content {
        guard let segment else {
            return fallback(appName: appName, store: store, mode: .arabicAndTranslation)
        }
        return Content(
            title: segment.arabic,
            subtitle: segment.subtitle,
            primaryButton: ShieldAyahProvider.primaryLabel(appName: appName, store: store),
            secondaryButton: segment.secondaryLabel
        )
    }

    private static func arabicOnlyContent(
        segment: ShieldAyahProvider.Segmented?,
        appName: String,
        store: AppGroupStore
    ) -> Content {
        guard let segment else {
            return fallback(appName: appName, store: store, mode: .arabicOnly)
        }
        return Content(
            title: segment.arabic,
            subtitle: segment.reference,
            primaryButton: ShieldAyahProvider.primaryLabel(appName: appName, store: store),
            secondaryButton: segment.secondaryLabel
        )
    }

    private static func translationOnlyContent(
        segment: ShieldAyahProvider.Segmented?,
        appName: String,
        store: AppGroupStore
    ) -> Content {
        guard let segment else {
            return fallback(appName: appName, store: store, mode: .translationOnly)
        }
        return Content(
            title: segment.translation,
            subtitle: segment.reference,
            primaryButton: ShieldAyahProvider.primaryLabel(appName: appName, store: store),
            secondaryButton: segment.secondaryLabel
        )
    }

    private static func fallback(
        appName: String,
        store: AppGroupStore,
        mode: ShieldLayoutMode
    ) -> Content {
        switch mode {
        case .none:
            return noneContent(segment: nil, appName: appName, store: store)
        case .translationOnly:
            return Content(
                title: "Open IqraLock to load today's ayah",
                subtitle: store.shieldSubtitle(),
                primaryButton: "Read in IqraLock",
                secondaryButton: nil
            )
        default:
            return Content(
                title: "\(appName) is locked",
                subtitle: store.shieldSubtitle(),
                primaryButton: ShieldAyahProvider.primaryLabel(appName: appName, store: store),
                secondaryButton: "Read another ayah"
            )
        }
    }

    private static func rejectionTitle(
        mode: ShieldLayoutMode,
        segment: ShieldAyahProvider.Segmented?
    ) -> String {
        switch mode {
        case .none:
            return "Almost — read in IqraLock"
        case .translationOnly:
            return segment?.translation ?? "Take a moment"
        default:
            return segment?.arabic ?? "Take a moment"
        }
    }

    private static func primaryButtonLabel(
        mode: ShieldLayoutMode,
        appName: String,
        store: AppGroupStore
    ) -> String {
        switch mode {
        case .none:
            return "Read in IqraLock"
        default:
            return ShieldAyahProvider.primaryLabel(appName: appName, store: store)
        }
    }

    private static func secondaryButtonLabel(
        mode: ShieldLayoutMode,
        segment: ShieldAyahProvider.Segmented?
    ) -> String? {
        switch mode {
        case .none:
            return nil
        default:
            return segment?.secondaryLabel ?? "Read another ayah"
        }
    }
}
