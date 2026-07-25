import SwiftUI
import SwiftData
import IqraLockKit

struct YouView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showShieldPreview = false
    @State private var showAbout = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Name", value: profile?.displayName ?? appModel.store.userDisplayName)
                    stepperRow
                    Picker("Reading style", selection: readingStyleBinding) {
                        ForEach(ReadingStyleAnswer.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    LabeledContent("Translation", value: "Saheeh International")
                    HStack {
                        Text("Arabic text size")
                        Spacer()
                        Text("\(Int(profile?.arabicTextSize ?? 26))pt")
                            .foregroundStyle(IQColor.textSecondary)
                    }
                } header: {
                    Text("Reading")
                }

                Section("Focus") {
                    LabeledContent("Locked apps", value: "\(appModel.screenTime.selectedAppCount) selected")
                    LabeledContent("Emergency passes", value: "\(appModel.store.emergencyPassesRemaining) left")
                    Button("Preview lock screen") { showShieldPreview = true }
                    if !appModel.purchases.gate.canBlockApps {
                        Text("Blocking requires Pro")
                            .font(.footnote)
                            .foregroundStyle(IQColor.textSecondary)
                    }
                }

                Section("Reminders") {
                    LabeledContent(
                        "Reminder time",
                        value: String(format: "%02d:%02d", profile?.reminderHour ?? 21, profile?.reminderMinute ?? 0)
                    )
                }

                Section("Subscription") {
                    LabeledContent("Status", value: appModel.purchases.hasPro ? "Pro" : "Free")
                    Button("Restore purchases") {
                        Task { try? await appModel.purchases.restore() }
                    }
                    if !appModel.purchases.hasPro {
                        Text("Pro unlocks app blocking, stats, transliteration, and extra passes. The Qur'an reader stays free.")
                            .font(.footnote)
                            .foregroundStyle(IQColor.textSecondary)
                    }
                }

                Section("Legal") {
                    Button("About & attributions") { showAbout = true }
                    Link("Privacy Policy", destination: URL(string: "https://iqralock.app/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://iqralock.app/terms")!)
                }
            }
            .navigationTitle("You")
            .sheet(isPresented: $showShieldPreview) {
                ShieldPreviewView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
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
