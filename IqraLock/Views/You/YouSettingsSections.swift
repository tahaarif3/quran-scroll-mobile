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
    @State private var showTimeAdjustments = false

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

            Button {
                showTimeAdjustments = true
            } label: {
                HStack {
                    Text("Adjust prayer times")
                        .foregroundStyle(IQColor.textPrimary)
                    Spacer()
                    if PrayerTimeSettings.load(profile: profile, store: appModel.store).hasAny {
                        Text("Custom")
                            .foregroundStyle(IQColor.accentOlive)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IQColor.textFaint)
                }
            }
            .disabled(selectedCity == nil)

            DatePicker(
                "Reading reminder",
                selection: reminderBinding,
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text("Prayer & reminders")
        } footer: {
            Text("Salah times are calculated for your city. Adjust them to match your local masjid.")
        }
        .sheet(isPresented: $showCityPicker) {
            PrayerCityPickerSheet(
                selectedCityID: $prayerCityID,
                profile: profile,
                onCitySelected: reschedulePrayerNotificationsIfNeeded
            )
        }
        .sheet(isPresented: $showTimeAdjustments) {
            PrayerTimeAdjustmentsSheet(profile: profile)
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

struct PrayerTimeAdjustmentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var profile: UserProfile?

    @State private var adjustments = PrayerTimeAdjustments.none
    @State private var pickedTimes: [PrayerName: Date] = [:]

    private var coordinates: (latitude: Double, longitude: Double)? {
        PrayerCitySelection.coordinates(profile: profile, store: appModel.store)
    }

    private var calculatedTimes: PrayerTimes? {
        guard let coords = coordinates else { return nil }
        return PrayerTimesCalculator.compute(
            latitude: coords.latitude,
            longitude: coords.longitude
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if calculatedTimes == nil {
                    Text("Choose your city first to see calculated salah times.")
                        .foregroundStyle(IQColor.textMuted)
                } else {
                    ForEach(PrayerName.allCases) { prayer in
                        adjustmentRow(for: prayer)
                    }

                    if adjustments.hasAny {
                        Button("Reset all to calculated times", role: .destructive) {
                            resetAll()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationTitle("Prayer times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .foregroundStyle(IQColor.brandPrimary)
                }
            }
            .toolbarBackground(IQColor.bgSand, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .onAppear(perform: loadState)
    }

    @ViewBuilder
    private func adjustmentRow(for prayer: PrayerName) -> some View {
        if let calculated = calculatedTimes?.time(for: prayer) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(prayer.displayName)
                        .font(.custom("Nunito-Bold", size: 17))
                        .foregroundStyle(IQColor.textInk)
                    Spacer()
                    if adjustments.isAdjusted(prayer) {
                        Text(offsetLabel(for: prayer))
                            .font(.custom("Nunito-Regular", size: 13))
                            .foregroundStyle(IQColor.accentOlive)
                    }
                }

                Text("Calculated: \(calculated, format: .dateTime.hour().minute())")
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundStyle(IQColor.textMuted2)

                DatePicker(
                    "Your time",
                    selection: binding(for: prayer, calculated: calculated),
                    displayedComponents: .hourAndMinute
                )
                .font(.custom("Nunito-Regular", size: 16))
                .foregroundStyle(IQColor.textInk)

                if adjustments.isAdjusted(prayer) {
                    Button("Use calculated time") {
                        setOffset(0, for: prayer, calculated: calculated)
                    }
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(IQColor.brandPrimary)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(IQColor.bgCard)
        }
    }

    private func binding(for prayer: PrayerName, calculated: Date) -> Binding<Date> {
        Binding(
            get: {
                pickedTimes[prayer]
                    ?? PrayerTimeOffsetMath.adjustedTime(
                        calculated: calculated,
                        offsetMinutes: adjustments.offset(for: prayer)
                    )
            },
            set: { newValue in
                pickedTimes[prayer] = newValue
                let offset = PrayerTimeOffsetMath.offsetMinutes(from: calculated, to: newValue)
                setOffset(offset, for: prayer, calculated: calculated)
            }
        )
    }

    private func loadState() {
        adjustments = PrayerTimeSettings.load(profile: profile, store: appModel.store)
        pickedTimes = [:]
    }

    private func setOffset(_ offset: Int, for prayer: PrayerName, calculated: Date) {
        adjustments.setOffset(offset, for: prayer)
        pickedTimes[prayer] = PrayerTimeOffsetMath.adjustedTime(
            calculated: calculated,
            offsetMinutes: offset
        )
        persistAdjustments()
    }

    private func resetAll() {
        adjustments.resetAll()
        pickedTimes = [:]
        persistAdjustments()
    }

    private func persistAdjustments() {
        appModel.applyPrayerTimeAdjustments(adjustments, profile: profile, context: modelContext)
    }

    private func saveAndDismiss() {
        persistAdjustments()
        dismiss()
    }

    private func offsetLabel(for prayer: PrayerName) -> String {
        let offset = adjustments.offset(for: prayer)
        let sign = offset > 0 ? "+" : ""
        return "\(sign)\(offset) min"
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
