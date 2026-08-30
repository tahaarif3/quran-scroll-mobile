import SwiftUI
import SwiftData
import IqraLockKit

#if canImport(FamilyControls)
import FamilyControls
#endif

struct YouView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showShieldPreview = false
    @State private var showAbout = false
    @State private var showPassConfirm = false
    @State private var showPINEntry = false
    @State private var showPINSetup = false
    @State private var pendingProtectedAction: (() -> Void)?
    @State private var showScreenTimeSetup = false
    @State private var showDisconnectConfirm = false
    @State private var showPaywall = false
    @State private var paywallPlan: PaywallPlan = .annual

    // Mirrors of App Group values. AppGroupStore is a plain class over UserDefaults with no
    // observation, so binding a control straight to it left the control frozen — the value
    // changed underneath and SwiftUI never re-rendered. These hold the live value; the store is
    // written through on change.
    @State private var goalAyahs: Int = 30
    @State private var ayahMinutes: Int = 30
    @State private var perPage: Int = 10
    @State private var arabicSize: Double = 26
    @State private var prayerLat: Double = 0
    @State private var prayerLon: Double = 0
    @State private var prayerNotifications = false
    #if canImport(FamilyControls)
    @State private var activitySelection = FamilyActivitySelection()
    @State private var showActivityPicker = false
    #endif
    #if DEBUG
    @State private var showResetConfirm = false
    #endif

    private var profile: UserProfile? { profiles.first }

    private var connection: ScreenTimeConnectionState { appModel.screenTimeConnection }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your name", text: nameBinding)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .foregroundStyle(IQColor.textSecondary)
                    }
                    // Continuous from a single ayah to ten pages. A whole-page stepper could not
                    // express a goal smaller than a page, which is exactly the size of goal
                    // someone starting out — or restarting after a bad week — needs.
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Daily goal")
                            Spacer()
                            Text(goalLabel)
                                .foregroundStyle(IQColor.textSecondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(goalAyahs) },
                                set: { goalAyahs = Int($0.rounded()) }
                            ),
                            in: 1...Double(perPage * 10),
                            step: 1
                        )
                        .tint(IQColor.accentOlive)
                        HStack {
                            Text("1 ayah").iqraStyle(.finePrint, color: IQColor.textFaint)
                            Spacer()
                            Text("10 pages").iqraStyle(.finePrint, color: IQColor.textFaint)
                        }
                    }
                    .onChange(of: goalAyahs) { _, new in
                        appModel.store.dailyGoalAyahs = new
                        profile?.dailyGoalPages = appModel.store.dailyGoalPages
                        try? modelContext.save()
                        // Raising the goal past what has been read today un-meets it, so the
                        // apps have to go back behind the shield. Without this the user could
                        // finish a one-ayah goal, raise it to ten pages, and stay unlocked.
                        appModel.shield.reevaluate()
                    }

                    Picker("Reading style", selection: readingStyleBinding) {
                        ForEach(ReadingStyleAnswer.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    Stepper(value: $arabicSize, in: 20...40, step: 1) {
                        HStack {
                            Text("Arabic text size")
                            Spacer()
                            Text("\(Int(arabicSize))pt")
                                .foregroundStyle(IQColor.textSecondary)
                        }
                    }
                    .onChange(of: arabicSize) { _, new in
                        profile?.arabicTextSize = new
                        try? modelContext.save()
                    }
                    // Only one translation ships with the app, so a picker here would be a
                    // control with a single option. Left as a plain row until there are more.
                    LabeledContent("Translation", value: "Saheeh International")
                } header: {
                    Text("Reading")
                }

                Section("Prayer times") {
                    Toggle("Prayer notifications", isOn: $prayerNotifications)
                        .onChange(of: prayerNotifications) { _, enabled in
                            profile?.prayerNotificationsEnabled = enabled
                            try? modelContext.save()
                            if enabled {
                                appModel.schedulePrayerNotificationsIfEnabled(context: modelContext)
                            } else {
                                appModel.notifications.cancelPrayerNotifications()
                            }
                        }
                    HStack {
                        Text("Latitude")
                        Spacer()
                        TextField("e.g. 33.95", value: $prayerLat, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Longitude")
                        Spacer()
                        TextField("e.g. -83.37", value: $prayerLon, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                } footer: {
                    Text("Set your coordinates for local salah times. Find them in your phone's Maps app.")
                }

                Section("Focus") {
                    // Setup can be half-finished in two different ways, and the row has to say
                    // which — "0 selected" gave the same answer whether the user skipped the
                    // picker or never granted access at all.
                    switch connection {
                    case .connected:
                        Button {
                            showActivityPicker = true
                        } label: {
                            HStack {
                                Text("Locked apps").foregroundStyle(IQColor.textPrimary)
                                Spacer()
                                Text("\(appModel.store.selectedAppsCount) selected")
                                    .foregroundStyle(IQColor.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(IQColor.textFaint)
                            }
                        }
                        Button("Turn off app blocking", role: .destructive) {
                            requirePIN { showDisconnectConfirm = true }
                        }
                    case .unsupported:
                        LabeledContent("Locked apps", value: "Needs a device")
                    case .noAppsChosen, .notConnected, .declined:
                        Button {
                            showScreenTimeSetup = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(IQColor.star)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set up app blocking")
                                        .foregroundStyle(IQColor.textPrimary)
                                    Text(connection.summary)
                                        .font(.footnote)
                                        .foregroundStyle(IQColor.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(IQColor.textFaint)
                            }
                        }
                    }
                    Stepper(value: $ayahMinutes, in: 5...120, step: 5) {
                        HStack {
                            Text("One ayah unlocks")
                            Spacer()
                            Text("\(ayahMinutes) min")
                                .foregroundStyle(IQColor.textSecondary)
                        }
                    }
                    .onChange(of: ayahMinutes) { _, new in appModel.store.ayahUnlockMinutes = new }

                    Stepper(value: $perPage, in: 1...30) {
                        HStack {
                            Text("Ayahs per page")
                            Spacer()
                            Text("\(perPage)")
                                .foregroundStyle(IQColor.textSecondary)
                        }
                    }
                    .onChange(of: perPage) { _, new in
                        appModel.store.ayahsPerPage = new
                        // Keep the goal where the user put it in ayahs; only its page-equivalent
                        // label moves when the conversion rate changes.
                        goalAyahs = min(goalAyahs, new * 10)
                    }

                    // Moved off the shield deliberately: a pass one tap away from the thing you
                    // are trying not to open is not much of a brake. Coming into the app for it
                    // is the friction.
                    LabeledContent("Bathroom breaks", value: "\(appModel.store.bathroomBreaksRemaining) left")
                    Button("Use a bathroom break (5 min)") {
                        requirePIN { showPassConfirm = true }
                    }
                    .disabled(appModel.store.bathroomBreaksRemaining == 0)
                    Button("Preview lock screen") { showShieldPreview = true }
                }

                Section("Family") {
                    if PINStore.isConfigured {
                        LabeledContent("Parent PIN", value: "On")
                        Button("Change PIN") { showPINSetup = true }
                    } else {
                        Button("Set up parent PIN") { showPINSetup = true }
                    }
                } footer: {
                    Text("Child mode: settings, bathroom breaks, and turning off blocking require the parent PIN.")
                }

                Section("Reminders") {
                    DatePicker(
                        "Reminder time",
                        selection: reminderBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section {
                    LabeledContent(
                        "Plan",
                        value: appModel.purchases.hasPro ? "Pro" : "Free"
                    )
                    Button("Restore purchases") {
                        Task { try? await appModel.purchases.restore() }
                    }
                    if !appModel.purchases.hasPro {
                        Button("Join Pro") { showPaywall = true }
                    }
                } header: {
                    Text("Pro")
                } footer: {
                    // Names the tier and tells the truth about it in the same breath. The old
                    // copy sold blocking, stats and extra passes as Pro while the app handed all
                    // three to everyone — a paywall that was never actually there.
                    Text(appModel.purchases.hasPro
                        ? "Thank you. Every feature is included for everyone today, so your subscription is support — Pro extras are coming, and you'll have them."
                        : "Every feature is already yours — blocking, stats, passes, all of it. Joining Pro adds nothing today; it's a donation that keeps the app going, and Pro-only features are on the way.")
                }

                Section("Legal") {
                    Button("About & attributions") { showAbout = true }
                    Link("Privacy Policy", destination: URL(string: "https://iqralock.app/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://iqralock.app/terms")!)
                }

                #if DEBUG
                Section {
                    Button("Reset to first run", role: .destructive) { showResetConfirm = true }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Clears onboarding, profile, reading history and shield state, then returns to the welcome screen. Debug builds only — avoids reinstalling to re-test onboarding.")
                }
                #endif
            }
            .navigationTitle("You")
            .onAppear { syncFromStore() }
            .onChange(of: prayerLat) { _, _ in savePrayerLocation() }
            .onChange(of: prayerLon) { _, _ in savePrayerLocation() }
            #if canImport(FamilyControls)
            .familyActivityPicker(isPresented: $showActivityPicker, selection: $activitySelection)
            .onChange(of: activitySelection) { _, newValue in
                try? FamilyActivitySelectionStore.save(newValue, to: appModel.store)
                let count = newValue.applicationTokens.count + newValue.categoryTokens.count
                appModel.screenTime.persistSelectionCount(count)
                // Re-apply immediately so removing an app unblocks it without waiting for the
                // next day roll, and adding one takes effect straight away.
                appModel.shield.reevaluate()
            }
            .onAppear {
                // Seed from the saved selection so reopening the picker shows current choices
                // as ticked rather than an empty list.
                if let saved = FamilyActivitySelectionStore.load(from: appModel.store) {
                    activitySelection = saved
                }
            }
            #endif
            .confirmationDialog(
                "Use a bathroom break?",
                isPresented: $showPassConfirm,
                titleVisibility: .visible
            ) {
                Button("Open apps for 5 minutes", role: .destructive) {
                    _ = appModel.screenTime.consumeBathroomBreak(durationMinutes: 5)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your apps open for 5 minutes. You have \(appModel.store.bathroomBreaksRemaining) left this month.")
            }
            .sheet(isPresented: $showPINSetup) {
                ParentPINSetupView()
            }
            .sheet(isPresented: $showPINEntry) {
                PINEntryView(
                    title: "Parent PIN",
                    subtitle: "Enter your PIN to continue.",
                    onSuccess: {
                        showPINEntry = false
                        pendingProtectedAction?()
                        pendingProtectedAction = nil
                    },
                    onCancel: {
                        showPINEntry = false
                        pendingProtectedAction = nil
                    }
                )
            }
            .sheet(isPresented: $showShieldPreview) {
                ShieldPreviewView()
            }
            .sheet(isPresented: $showScreenTimeSetup) {
                ScreenTimeSetupView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(
                    purchases: appModel.purchases,
                    selectedPlan: $paywallPlan,
                    onSkip: { showPaywall = false },
                    onPurchase: {
                        Task {
                            // Purchase failures are surfaced by the paywall itself; the sheet
                            // stays up so a declined card doesn't look like a silent success.
                            do {
                                switch paywallPlan {
                                case .annual: try await appModel.purchases.purchaseAnnual()
                                case .weekly: try await appModel.purchases.purchaseWeekly()
                                }
                                showPaywall = false
                            } catch {
                                appModel.analytics.track("purchase_failed", properties: [
                                    "plan": paywallPlan.rawValue,
                                    "error": String(describing: error)
                                ])
                            }
                        }
                    },
                    onRestore: { Task { try? await appModel.purchases.restore() } }
                )
            }
            .confirmationDialog(
                "Turn off app blocking?",
                isPresented: $showDisconnectConfirm,
                titleVisibility: .visible
            ) {
                Button("Turn off blocking", role: .destructive) {
                    Task { await appModel.screenTime.disconnect() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your apps open normally again and your choice of locked apps is cleared. Your reading, streak and khatm are untouched. You can set it up again any time.")
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            #if DEBUG
            .confirmationDialog(
                "Reset to first run?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset everything", role: .destructive) {
                    appModel.resetToFirstRun(modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes your profile, streak, reading history and app selection. This cannot be undone.")
            }
            #endif
        }
    }



    /// Mirrored into the App Group as well as the profile: Home greets from the store, and the
    /// shield extensions read it too, so writing only the SwiftData copy leaves the name stale
    /// everywhere outside this screen.
    private var nameBinding: Binding<String> {
        Binding(
            get: { profile?.displayName ?? appModel.store.userDisplayName },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                profile?.displayName = trimmed
                appModel.store.userDisplayName = trimmed
                try? modelContext.save()
            }
        )
    }

    /// Matches the range of the reader's own text-size sheet, so the two controls cannot
    /// disagree about what sizes are allowed.

    /// Hour and minute are stored as separate integers; DatePicker wants a Date. The date part
    /// is irrelevant — only the time components are read back.
    private var reminderBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = profile?.reminderHour ?? 21
                components.minute = profile?.reminderMinute ?? 0
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let hour = components.hour ?? 21
                let minute = components.minute ?? 0
                profile?.reminderHour = hour
                profile?.reminderMinute = minute
                try? modelContext.save()
                // Rescheduled immediately — persisting the new time without re-registering the
                // notification would leave the reminder firing at the old one indefinitely.
                appModel.notifications.scheduleDailyReminder(hour: hour, minute: minute)
            }
        )
    }

    /// Reads the goal the way a person would say it: ayahs below a page, pages above.
    private var goalLabel: String {
        if goalAyahs < perPage {
            return goalAyahs == 1 ? "1 ayah" : "\(goalAyahs) ayahs"
        }
        let pages = Int(ceil(Double(goalAyahs) / Double(max(1, perPage))))
        let remainder = goalAyahs % max(1, perPage)
        let base = pages == 1 ? "1 page" : "\(pages) pages"
        return remainder == 0 ? base : "\(goalAyahs) ayahs · about \(base)"
    }

    /// Pulls the App Group values into the local mirrors once the view is on screen.
    private func syncFromStore() {
        goalAyahs = appModel.store.dailyGoalAyahs
        ayahMinutes = appModel.store.ayahUnlockMinutes
        perPage = appModel.store.ayahsPerPage
        arabicSize = profile?.arabicTextSize ?? 26
        prayerLat = profile?.prayerLatitude ?? 0
        prayerLon = profile?.prayerLongitude ?? 0
        prayerNotifications = profile?.prayerNotificationsEnabled ?? false
    }

    private func savePrayerLocation() {
        profile?.prayerLatitude = prayerLat
        profile?.prayerLongitude = prayerLon
        try? modelContext.save()
        if prayerNotifications {
            appModel.schedulePrayerNotificationsIfEnabled(context: modelContext)
        }
    }

    private func requirePIN(_ action: @escaping () -> Void) {
        if PINStore.isConfigured {
            pendingProtectedAction = action
            showPINEntry = true
        } else {
            action()
        }
    }

    private var readingStyleBinding: Binding<ReadingStyleAnswer> {
        Binding(
            get: { profile?.readingStyle ?? .arabicTranslation },
            set: { newValue in
                profile?.readingStyleRaw = newValue.rawValue
                try? modelContext.save()
            }
        )
    }
}

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About IqraLock")
                        .iqraStyle(.h2)

                    Text("Arabic text")
                        .iqraStyle(.bodyStrong)
                    Text("The Uthmani Qur'an text is provided by the Tanzil Project (CC BY 3.0). Commercial use is permitted with attribution. The text is distributed verbatim — no letters or diacritics have been modified.")
                        .iqraStyle(.body, color: IQColor.textSecondary)
                    Link("https://tanzil.net", destination: URL(string: "https://tanzil.net")!)
                        .iqraStyle(.bodyStrong, color: IQColor.olive)

                    Text("Copyright © Tanzil Project. Licensed under Creative Commons Attribution 3.0.")
                        .iqraStyle(.caption, color: IQColor.textSecondary)

                    Text("English translation")
                        .iqraStyle(.bodyStrong)
                    Text("Saheeh International — Abul-Qasim Publishing House. Served for display via quran.com API v4; bundled for offline first-run.")
                        .iqraStyle(.body, color: IQColor.textSecondary)

                    Text("Third-party")
                        .iqraStyle(.bodyStrong)
                    Text("Fonts: Nunito & Amiri (SIL Open Font License).\nSDKs (when enabled): RevenueCat, PostHog, swift-snapshot-testing.")
                        .iqraStyle(.body, color: IQColor.textSecondary)
                }
                .padding(IQSpace.gutter)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
