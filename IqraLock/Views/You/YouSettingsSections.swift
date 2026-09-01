import SwiftUI
import SwiftData
import IqraLockKit

struct PrayerCityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedCityID: String
    var profile: UserProfile?
    var onCitySelected: (() -> Void)?
    @State private var query = ""

    private var results: [PrayerCity] {
        PrayerCityCatalog.search(query)
    }

    var body: some View {
        NavigationStack {
            List(results) { city in
                Button {
                    select(city)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name)
                                .font(.custom("Nunito-Bold", size: 17))
                                .foregroundStyle(IQColor.textInk)
                            Text(city.region)
                                .font(.custom("Nunito-Regular", size: 14))
                                .foregroundStyle(IQColor.textMuted2)
                        }
                        Spacer()
                        if city.id == selectedCityID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(IQColor.accentOlive)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(IQColor.bgCard)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(IQColor.bgSand.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search your city")
            .navigationTitle("Nearby city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IQColor.brandPrimary)
                }
            }
            .toolbarBackground(IQColor.bgSand, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private func select(_ city: PrayerCity) {
        selectedCityID = city.id
        appModel.applyPrayerCity(city, profile: profile, context: modelContext)
        onCitySelected?()
        dismiss()
    }
}

struct YouPrayerSettingsSection: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Binding var prayerNotifications: Bool
    @Binding var prayerCityID: String
    var profile: UserProfile?

    @State private var showCityPicker = false

    private var selectedCity: PrayerCity? {
        PrayerCityCatalog.city(id: prayerCityID) ?? profile?.selectedPrayerCity
    }

    var body: some View {
        Section {
            Button {
                showCityPicker = true
            } label: {
                HStack {
                    Text("City")
                        .foregroundStyle(IQColor.textPrimary)
                    Spacer()
                    Text(selectedCity?.label ?? "Choose a city")
                        .foregroundStyle(IQColor.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IQColor.textFaint)
                }
            }

            Toggle("Prayer notifications", isOn: $prayerNotifications)
                .onChange(of: prayerNotifications) { _, enabled in
                    profile?.prayerNotificationsEnabled = enabled
                    try? modelContext.save()
                    reschedulePrayerNotificationsIfNeeded()
                }

            DatePicker(
                "Reading reminder",
                selection: reminderBinding,
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text("Prayer & reminders")
        } footer: {
            Text("Salah times are calculated for your city. No coordinates needed.")
        }
        .sheet(isPresented: $showCityPicker) {
            PrayerCityPickerSheet(
                selectedCityID: $prayerCityID,
                profile: profile,
                onCitySelected: reschedulePrayerNotificationsIfNeeded
            )
        }
        .onChange(of: prayerCityID) { _, newID in
            guard let city = PrayerCityCatalog.city(id: newID) else { return }
            appModel.applyPrayerCity(city, profile: profile, context: modelContext)
            reschedulePrayerNotificationsIfNeeded()
        }
    }

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
                profile?.reminderHour = components.hour ?? 21
                profile?.reminderMinute = components.minute ?? 0
                try? modelContext.save()
                appModel.notifications.scheduleDailyReminder(
                    hour: profile?.reminderHour ?? 21,
                    minute: profile?.reminderMinute ?? 0
                )
            }
        )
    }

    private func reschedulePrayerNotificationsIfNeeded() {
        if prayerNotifications {
            appModel.schedulePrayerNotificationsIfEnabled(context: modelContext)
        } else {
            appModel.notifications.cancelPrayerNotifications()
        }
    }
}

struct YouShieldLayoutSection: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Binding var shieldLayoutMode: ShieldLayoutMode
    @Binding var showShieldPreview: Bool
    var profile: UserProfile?

    var body: some View {
        Section {
            Picker("Lock screen layout", selection: $shieldLayoutMode) {
                ForEach(ShieldLayoutMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .onChange(of: shieldLayoutMode) { _, newMode in
                applyLayout(newMode)
            }

            Button {
                showShieldPreview = true
            } label: {
                HStack {
                    Text("Preview lock screens")
                        .foregroundStyle(IQColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IQColor.textFaint)
                }
            }
        } header: {
            Text("Lock screen")
        } footer: {
            Text(shieldLayoutMode.detail)
        }
    }

    private func applyLayout(_ mode: ShieldLayoutMode) {
        appModel.store.shieldLayoutMode = mode
        profile?.shieldLayoutMode = mode
        try? modelContext.save()
        appModel.shield.refreshShieldAppearance()
    }
}

struct YouFamilySection: View {
    @Binding var showPINSetup: Bool

    var body: some View {
        Section {
            if PINStore.isConfigured {
                LabeledContent("Parent PIN", value: "On")
                Button("Change PIN") { showPINSetup = true }
            } else {
                Button("Set up parent PIN") { showPINSetup = true }
            }
        } header: {
            Text("Family")
        } footer: {
            Text("Bathroom breaks and turning off blocking require the parent PIN when set.")
        }
    }
}
