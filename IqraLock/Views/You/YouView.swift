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
    @State private var showAbout = false
    @State private var showPassConfirm = false
    @State private var showPINEntry = false
    @State private var showPINSetup = false
    @State private var pendingProtectedAction: (() -> Void)?
    @State private var showScreenTimeSetup = false
    @State private var showDisconnectConfirm = false

    @State private var goalAyahs: Int = 30
    @State private var ayahMinutes: Int = 30
    @State private var prayerCityID: String = ""
    @State private var prayerNotifications = false
    @State private var shieldLayoutMode: ShieldLayoutMode = .arabicAndTranslation
    @State private var showShieldPreview = false
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
                profileSection
                YouPrayerSettingsSection(
                    prayerNotifications: $prayerNotifications,
                    prayerCityID: $prayerCityID,
                    profile: profile
                )
                YouShieldLayoutSection(
                    shieldLayoutMode: $shieldLayoutMode,
                    showShieldPreview: $showShieldPreview,
                    profile: profile
                )
                focusSection
                YouFamilySection(showPINSetup: $showPINSetup)
                legalSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("You")
            .onAppear { syncFromStore() }
            .modifier(YouViewSheets(
                showPassConfirm: $showPassConfirm,
                showPINSetup: $showPINSetup,
                showPINEntry: $showPINEntry,
                showScreenTimeSetup: $showScreenTimeSetup,
                showDisconnectConfirm: $showDisconnectConfirm,
                showAbout: $showAbout,
                showShieldPreview: $showShieldPreview,
                pendingProtectedAction: $pendingProtectedAction,
                appModel: appModel,
                modelContext: modelContext
            ))
            #if DEBUG
            .confirmationDialog("Reset to first run?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    appModel.resetToFirstRun(modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
            #endif
            #if canImport(FamilyControls)
            .familyActivityPicker(isPresented: $showActivityPicker, selection: $activitySelection)
            .onChange(of: activitySelection) { _, newValue in
                try? FamilyActivitySelectionStore.save(newValue, to: appModel.store)
                let count = newValue.applicationTokens.count + newValue.categoryTokens.count
                appModel.screenTime.persistSelectionCount(count)
                appModel.shield.reevaluate()
            }
            .onAppear {
                if let saved = FamilyActivitySelectionStore.load(from: appModel.store) {
                    activitySelection = saved
                }
            }
            #endif
        }
    }

    private var profileSection: some View {
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
                    in: 1...Double(max(1, appModel.store.ayahsPerPage) * 10),
                    step: 1
                )
                .tint(IQColor.accentOlive)
            }
            .onChange(of: goalAyahs) { _, new in
                appModel.store.dailyGoalAyahs = new
                profile?.dailyGoalPages = appModel.store.dailyGoalPages
                try? modelContext.save()
                appModel.shield.reevaluate()
            }
        } header: {
            Text("You")
        }
    }

    private var focusSection: some View {
        Section("Focus") {
            switch connection {
            case .connected:
                Button { showActivityPicker = true } label: {
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
                Button { showScreenTimeSetup = true } label: {
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

            LabeledContent("Bathroom breaks", value: "\(appModel.store.bathroomBreaksRemaining) left")
            Button("Use a bathroom break (5 min)") {
                requirePIN { showPassConfirm = true }
            }
            .disabled(appModel.store.bathroomBreaksRemaining == 0)
        }
    }

    private var legalSection: some View {
        Section("About") {
            Button("About & attributions") { showAbout = true }
            Link("Privacy Policy", destination: URL(string: "https://iqralock.app/privacy")!)
            Link("Terms of Use", destination: URL(string: "https://iqralock.app/terms")!)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button("Reset to first run", role: .destructive) { showResetConfirm = true }
        } header: {
            Text("Debug")
        }
    }
    #endif

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

    private var goalLabel: String {
        let perPage = max(1, appModel.store.ayahsPerPage)
        if goalAyahs < perPage {
            return goalAyahs == 1 ? "1 ayah" : "\(goalAyahs) ayahs"
        }
        let pages = Int(ceil(Double(goalAyahs) / Double(perPage)))
        return pages == 1 ? "1 page" : "\(pages) pages"
    }

    private func syncFromStore() {
        goalAyahs = appModel.store.dailyGoalAyahs
        ayahMinutes = appModel.store.ayahUnlockMinutes
        prayerNotifications = profile?.prayerNotificationsEnabled ?? false
        shieldLayoutMode = profile?.shieldLayoutMode ?? appModel.store.shieldLayoutMode
        appModel.store.shieldLayoutMode = shieldLayoutMode

        if let profile {
            if !profile.prayerCityId.isEmpty {
                prayerCityID = profile.prayerCityId
            } else if let nearest = profile.selectedPrayerCity {
                prayerCityID = nearest.id
                appModel.applyPrayerCity(nearest, profile: profile, context: modelContext)
            } else if prayerCityID.isEmpty, let defaultCity = PrayerCityCatalog.city(id: PrayerCityCatalog.defaultCityID) {
                prayerCityID = defaultCity.id
                appModel.applyPrayerCity(defaultCity, profile: profile, context: modelContext)
            }
        } else if !appModel.store.prayerCityId.isEmpty {
            prayerCityID = appModel.store.prayerCityId
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
}

// Sheets and dialogs extracted so the main `body` type-checks quickly in CI.
private struct YouViewSheets: ViewModifier {
    @Binding var showPassConfirm: Bool
    @Binding var showPINSetup: Bool
    @Binding var showPINEntry: Bool
    @Binding var showScreenTimeSetup: Bool
    @Binding var showDisconnectConfirm: Bool
    @Binding var showAbout: Bool
    @Binding var showShieldPreview: Bool
    @Binding var pendingProtectedAction: (() -> Void)?
    let appModel: AppModel
    let modelContext: ModelContext

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Use a bathroom break?", isPresented: $showPassConfirm, titleVisibility: .visible) {
                Button("Open apps for 5 minutes", role: .destructive) {
                    _ = appModel.screenTime.consumeBathroomBreak(durationMinutes: 5)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your apps open for 5 minutes.")
            }
            .sheet(isPresented: $showPINSetup) { ParentPINSetupView() }
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
            .sheet(isPresented: $showScreenTimeSetup) { ScreenTimeSetupView() }
            .sheet(isPresented: $showAbout) { AboutView() }
            .sheet(isPresented: $showShieldPreview) { ShieldPreviewView() }
            .confirmationDialog("Turn off app blocking?", isPresented: $showDisconnectConfirm, titleVisibility: .visible) {
                Button("Turn off blocking", role: .destructive) {
                    Task { await appModel.screenTime.disconnect() }
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About IqraLock")
                        .iqraStyle(.h2)
                    Text("Arabic text from the Tanzil Project (CC BY 3.0). English translation: Saheeh International.")
                        .iqraStyle(.body, color: IQColor.textSecondary)
                    Link("https://tanzil.net", destination: URL(string: "https://tanzil.net")!)
                        .iqraStyle(.bodyStrong, color: IQColor.olive)
                }
                .padding(IQSpace.gutter)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
