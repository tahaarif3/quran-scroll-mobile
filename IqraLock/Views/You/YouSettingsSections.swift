import SwiftUI
import SwiftData
import IqraLockKit

struct YouPrayerSettingsSection: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Binding var prayerNotifications: Bool
    @Binding var prayerLat: Double
    @Binding var prayerLon: Double
    var profile: UserProfile?

    var body: some View {
        Section {
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
        } header: {
            Text("Prayer times")
        } footer: {
            Text("Set your coordinates for local salah times. Find them in your phone's Maps app.")
        }
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
            Text("Child mode: settings, bathroom breaks, and turning off blocking require the parent PIN.")
        }
    }
}
