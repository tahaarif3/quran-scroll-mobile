import SwiftUI
import IqraLockKit
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

/// The one screen that repairs a half-finished Screen Time setup.
///
/// Onboarding asks for authorization and an app selection as two separate steps, and either can
/// be declined or skipped. The result looks like a working install — the home screen counts
/// ayahs, the goal fills, the copy talks about locked apps — while nothing is ever blocked. This
/// is reachable from You at any time, and is what the launch reminder presents, so there is
/// exactly one path from any broken state back to a working one.
struct ScreenTimeSetupView: View {
    /// Presented as a reminder the user didn't ask for, rather than opened from settings. Adds
    /// the way out, and softens the heading from an instruction to an explanation.
    let isReminder: Bool

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var state: ScreenTimeConnectionState = .notConnected
    @State private var isRequesting = false
    #if canImport(FamilyControls)
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()
    #endif

    init(isReminder: Bool = false) {
        self.isReminder = isReminder
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    checklist
                    if state == .declined { settingsNote }
                }
                .padding(IQSpace.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isReminder {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    ChunkyButton(primaryTitle, enabled: !isRequesting) { performPrimaryAction() }
                    if isReminder {
                        Button {
                            dismiss()
                        } label: {
                            Text("Not now")
                                .iqraStyle(.captionStrong, color: IQColor.textMuted)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, IQSpace.gutterWide)
                .padding(.bottom, IQSpace.ctaBottom)
                .padding(.top, 10)
                .background(IQColor.bgSand.opacity(0.92))
            }
        }
        .onAppear { refresh() }
        #if canImport(FamilyControls)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _, newValue in
            persist(newValue)
        }
        #endif
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            IQIconView(.lock, size: 44)
            Text(title)
                .iqraStyle(.h1, color: IQColor.textInk)
            Text(explanation)
                .iqraStyle(.subtitle, color: IQColor.textMuted2)
        }
    }

    /// Both halves, shown together. Which one is missing is the whole question here, and a user
    /// who authorized but skipped the picker has no way to tell that from a screen that only
    /// says "not connected".
    private var checklist: some View {
        VStack(spacing: 0) {
            checklistRow(
                title: "Screen Time access",
                detail: hasAuthorization
                    ? "Granted"
                    : "IqraLock can't see your apps without it",
                isDone: hasAuthorization
            )
            Divider().overlay(IQColor.hairline)
            checklistRow(
                title: "Apps to lock",
                detail: appModel.store.selectedAppsCount > 0
                    ? "\(appModel.store.selectedAppsCount) selected"
                    : "Nothing chosen yet",
                isDone: appModel.store.selectedAppsCount > 0
            )
        }
        .background(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .fill(IQColor.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .strokeBorder(IQColor.borderSubtle, lineWidth: 1.6)
        )
    }

    private func checklistRow(title: String, detail: String, isDone: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isDone ? IQColor.accentOlive : IQColor.radioEmpty)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).iqraStyle(.bodyStrong, color: IQColor.textInk)
                Text(detail).iqraStyle(.caption, color: IQColor.textMuted2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(isDone ? "Done" : "Not done"). \(detail)")
    }

    /// Only shown once iOS has actually refused, so it never pre-emptively sends someone to
    /// Settings for a prompt the app can still raise itself.
    private var settingsNote: some View {
        Text("iOS only asks once. If tapping above doesn't bring up the prompt, it opens Settings instead — turn IqraLock on under Screen Time there.")
            .iqraStyle(.caption, color: IQColor.textMuted2)
    }

    // MARK: - Copy

    private var hasAuthorization: Bool {
        state == .connected || state == .noAppsChosen
    }

    private var title: String {
        switch state {
        case .connected: return "You're all set"
        case .noAppsChosen: return "Choose what to lock"
        case .notConnected: return isReminder ? "Nothing is locked yet" : "Connect to Screen Time"
        case .declined: return "Nothing is locked yet"
        case .unsupported: return "Not available here"
        }
    }

    private var explanation: String {
        switch state {
        case .connected:
            return "Your apps stay behind the shield until you've read today's ayahs."
        case .noAppsChosen:
            return "Screen Time is connected, but no apps are picked — so there's nothing for IqraLock to hold back. Choose the ones you reach for without thinking."
        case .notConnected:
            return "IqraLock uses Apple's Screen Time to shield your apps. Until it's connected, everything opens as normal and your reading unlocks nothing."
        case .declined:
            return "Screen Time access was declined, so IqraLock can't shield anything. The reading and streak still work — but nothing is being held back."
        case .unsupported:
            return "App blocking needs a real device with Screen Time. Everything else works here."
        }
    }

    private var primaryTitle: String {
        switch state {
        case .connected: return "Done"
        case .noAppsChosen: return "Choose apps to lock"
        case .notConnected: return "Connect Screen Time"
        case .declined: return "Allow Screen Time access"
        case .unsupported: return "Close"
        }
    }

    // MARK: - Actions

    private func performPrimaryAction() {
        switch state {
        case .connected, .unsupported:
            dismiss()
        case .noAppsChosen:
            presentPicker()
        case .notConnected, .declined:
            requestAuthorization()
        }
    }

    private func requestAuthorization() {
        isRequesting = true
        Task {
            let wasDeclined = state == .declined
            do {
                try await appModel.screenTime.requestAuthorization()
            } catch {
                appModel.analytics.track("screentime_auth_retry_failed", properties: [
                    "error": String(describing: error),
                    "surface": isReminder ? "reminder" : "settings"
                ])
            }
            refresh()
            isRequesting = false

            switch state {
            case .noAppsChosen:
                // Authorization on its own blocks nothing. Going straight to the picker is the
                // difference between finishing setup and landing back in the half-done state
                // this screen exists to fix.
                presentPicker()
            case .declined where wasDeclined:
                // Asked again and iOS didn't re-present its prompt. Settings is the only route
                // left, and the button promised access — so take them there rather than leaving
                // a tap that visibly does nothing.
                openSettings()
            default:
                break
            }
        }
    }

    private func presentPicker() {
        #if canImport(FamilyControls)
        if let saved = FamilyActivitySelectionStore.load(from: appModel.store) {
            selection = saved
        }
        showPicker = true
        #endif
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    #if canImport(FamilyControls)
    private func persist(_ newValue: FamilyActivitySelection) {
        // The encoded selection has to land in the App Group before the count, so anything
        // reacting to the count can already load real tokens.
        try? FamilyActivitySelectionStore.save(newValue, to: appModel.store)
        let count = newValue.applicationTokens.count + newValue.categoryTokens.count
        appModel.screenTime.persistSelectionCount(count)
        // Apply straight away — a selection that waits for the next day roll to take effect
        // looks exactly like a selection that didn't save.
        appModel.shield.reevaluate()
        refresh()
        if state == .connected {
            appModel.analytics.track("screentime_setup_completed", properties: [
                "surface": isReminder ? "reminder" : "settings",
                "apps": count
            ])
            dismiss()
        }
    }
    #endif

    private func refresh() {
        state = ScreenTimeConnection.state(screenTime: appModel.screenTime, store: appModel.store)
    }
}
