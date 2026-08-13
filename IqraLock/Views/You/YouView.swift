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
    #if canImport(FamilyControls)
    @State private var activitySelection = FamilyActivitySelection()
    @State private var showActivityPicker = false
    #endif
    #if DEBUG
    @State private var showResetConfirm = false
    #endif

    private var profile: UserProfile? { profiles.first }

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
                    stepperRow
                    Picker("Reading style", selection: readingStyleBinding) {
                        ForEach(ReadingStyleAnswer.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    Stepper(value: textSizeBinding, in: 20...36, step: 1) {
                        HStack {
                            Text("Arabic text size")
                            Spacer()
                            Text("\(Int(textSizeBinding.wrappedValue))pt")
                                .foregroundStyle(IQColor.textSecondary)
                        }
                    }
                    // Only one translation ships with the app, so a picker here would be a
                    // control with a single option. Left as a plain row until there are more.
                    LabeledContent("Translation", value: "Saheeh International")
                } header: {
                    Text("Reading")
                }

                Section("Focus") {
                    if ScreenTimeAvailability.isSupported {
                        Button {
                            showActivityPicker = true
                        } label: {
                            HStack {
                                Text("Locked apps").foregroundStyle(IQColor.textPrimary)
                                Spacer()
                                Text("\(appModel.screenTime.selectedAppCount) selected")
                                    .foregroundStyle(IQColor.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(IQColor.textFaint)
                            }
                        }
                    } else {
                        LabeledContent("Locked apps", value: "\(appModel.screenTime.selectedAppCount) selected")
                    }
                    Stepper(value: ayahMinutesBinding, in: 5...120, step: 5) {
                        HStack {
                            Text("One ayah unlocks")
                            Spacer()
                            Text("\(ayahMinutesBinding.wrappedValue) min")
                                .foregroundStyle(IQColor.textSecondary)
                        }
                    }
                    Stepper(value: ayahsPerPageBinding, in: 1...30) {
                        HStack {
                            Text("Ayahs per page")
                            Spacer()
                            Text("\(ayahsPerPageBinding.wrappedValue)")
                                .foregroundStyle(IQColor.textSecondary)
                        }
                    }

                    // Moved off the shield deliberately: a pass one tap away from the thing you
                    // are trying not to open is not much of a brake. Coming into the app for it
                    // is the friction.
                    LabeledContent("Emergency passes", value: "\(appModel.store.emergencyPassesRemaining) left")
                    Button("Use an emergency pass") { showPassConfirm = true }
                        .disabled(appModel.store.emergencyPassesRemaining == 0)
                    Button("Preview lock screen") { showShieldPreview = true }
                    if !appModel.purchases.gate.canBlockApps {
                        Text("Blocking requires Pro")
                            .font(.footnote)
                            .foregroundStyle(IQColor.textSecondary)
                    }
                }

                Section("Reminders") {
                    DatePicker(
                        "Reminder time",
                        selection: reminderBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Subscription") {
                    LabeledContent("Status", value: appModel.purchases.hasPro ? "Pro" : "Free")
                    Button("Restore purchases") {
                        Task { try? await appModel.purchases.restore() }
                    }
                    if !appModel.purchases.hasPro {
                        Text("Pro unlocks app blocking, stats, and extra passes. The Qur'an reader stays free.")
                            .font(.footnote)
                            .foregroundStyle(IQColor.textSecondary)
                    }
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
                "Use an emergency pass?",
                isPresented: $showPassConfirm,
                titleVisibility: .visible
            ) {
                Button("Unlock for 15 minutes", role: .destructive) {
                    _ = appModel.screenTime.consumeEmergencyPass(durationMinutes: 15)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your apps open for 15 minutes. You have \(appModel.store.emergencyPassesRemaining) left this month.")
            }
            .sheet(isPresented: $showShieldPreview) {
                ShieldPreviewView()
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

    private var stepperRow: some View {
        Stepper(value: goalBinding, in: 2...5) {
            Text("Daily goal: \(profile?.dailyGoalPages ?? appModel.store.dailyGoalPages) pages")
        }
    }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { profile?.dailyGoalPages ?? appModel.store.dailyGoalPages },
            set: { newValue in
                profile?.dailyGoalPages = newValue
                appModel.store.dailyGoalPages = newValue
                try? modelContext.save()
            }
        )
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
    private var textSizeBinding: Binding<Double> {
        Binding(
            get: { profile?.arabicTextSize ?? 26 },
            set: { newValue in
                profile?.arabicTextSize = newValue
                try? modelContext.save()
            }
        )
    }

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

    private var ayahMinutesBinding: Binding<Int> {
        Binding(
            get: { appModel.store.ayahUnlockMinutes },
            set: { appModel.store.ayahUnlockMinutes = $0 }
        )
    }

    private var ayahsPerPageBinding: Binding<Int> {
        Binding(
            get: { appModel.store.ayahsPerPage },
            set: { appModel.store.ayahsPerPage = $0 }
        )
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
