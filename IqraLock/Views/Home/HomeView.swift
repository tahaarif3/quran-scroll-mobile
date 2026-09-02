import SwiftUI
import SwiftData
import IqraLockKit
import UIKit

/// Home answers two questions in fixed positions: how long the apps are open, and what one more
/// ayah buys. Everything below the hero card is the means of doing it.
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]
    @Query(sort: \PrayerLog.day, order: .reverse) private var prayerLogs: [PrayerLog]

    @State private var ayah: Ayah?
    @State private var needsReadConfirmation = false
    @State private var repository: BundledQuranRepository?
    @State private var justRead = false
    @State private var revision = 0

    private var store: AppGroupStore { appModel.store }
    private var name: String { profiles.first?.displayName ?? store.userDisplayName }
    private var lockedCount: Int { appModel.screenTime.selectedAppCount }
    private var remainingAyahs: Int { max(0, store.dailyGoalAyahs - store.totalAyahsToday) }
    private var arabicSize: CGFloat { CGFloat(profiles.first?.arabicTextSize ?? 27) }

    private var stats: HabitStats {
        HabitStatsCalculator.compute(
            records: DailyProgressSync.recordsIncludingToday(
                stored: records,
                store: store,
                prayerLogs: prayerLogs
            )
        )
    }

    private var heroState: HomeHeroCard.State {
        if store.goalMetToday {
            return .goalMet(
                ayahs: store.totalAyahsToday,
                pages: store.pagesReadToday,
                sittings: max(1, store.sittingsToday)
            )
        }
        if let until = store.unlockedUntil, until > Date() {
            return remainingAyahs <= 6
                ? .partway(until: until, ayahsRead: store.totalAyahsToday, goal: store.dailyGoalAyahs)
                : .unlocked(until: until)
        }
        return .locked(closedApps: lockedCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    HomeHeroCard(state: heroState, unlockMinutes: store.ayahUnlockMinutes)
                        .id(revision)
                    ayahCard
                    readerLink
                    bathroomBreakNote
                }
                .padding(.horizontal, IQSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
            .onAppear {
                revision += 1
                appModel.syncDailyProgress(context: modelContext)
            }
            .sheet(isPresented: $needsReadConfirmation) {
                AyahReadConfirmationSheet(
                    onConfirm: {
                        needsReadConfirmation = false
                        credit(confirmed: true)
                    },
                    onCancel: { needsReadConfirmation = false }
                )
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Assalamu ʿalaykum,")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)
                Text(name)
                    .iqraStyle(.greetingName, color: IQColor.textInk)
            }
            Spacer()
            StreakPill(days: stats.streakDays)
        }
    }

    private var continueLabel: String {
        store.khatmCursor > 1 || store.totalAyahsToday > 0
            ? "CONTINUE WHERE YOU LEFT OFF"
            : "START HERE"
    }

    private var ayahCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(continueLabel)
                        .font(.custom("Nunito-ExtraBold", size: 11))
                        .tracking(0.8)
                        .foregroundStyle(IQColor.accentOlive)
                    Spacer()
                    Text(ayah?.verseKey ?? "")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                }

                Text(ayah?.textUthmani ?? "")
                    .font(.custom("Amiri-Bold", size: arabicSize))
                    .lineSpacing(arabicSize)
                    .foregroundStyle(IQColor.textInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)

                if profiles.first?.readingStyle != .arabicOnly {
                    Text(ayah?.translationEn ?? "")
                        .iqraStyle(.translation, color: IQColor.textMuted2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                primaryAction
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if store.goalMetToday {
            Button { appModel.showReader = true } label: {
                Text("Keep reading")
                    .font(IQFontStyle.button.font)
                    .foregroundStyle(IQColor.brandPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: IQSpace.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: IQRadius.button, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: IQRadius.button, style: .continuous)
                            .strokeBorder(IQColor.track, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
            Text("Nothing left to earn today. Anything more goes to your khatm — \(store.ayahsToKhatm) ayahs to go.")
                .iqraStyle(.finePrint, color: IQColor.textFaint)
        } else if remainingAyahs <= 6 && isUnlocked {
            ChunkyButton("Read the last \(remainingAyahs)  ·  ≈ \(max(1, remainingAyahs / 2)) min") {
                appModel.showReader = true
            }
            Text("Read one at a time →")
                .iqraStyle(.captionStrong, color: IQColor.brandPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            ChunkyButton(justRead ? "Counted  ·  +\(store.ayahUnlockMinutes) min" : "I've read it  ·  +\(store.ayahUnlockMinutes) min") {
                credit()
            }
        }
    }

    private var readerLink: some View {
        Button { appModel.showReader = true } label: {
            Text("Open the reader →")
                .iqraStyle(.captionStrong, color: IQColor.brandPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bathroomBreakNote: some View {
        Text("Need a quick break? Bathroom passes give 5 minutes. \(store.bathroomBreaksRemaining) left this month — find them in You.")
            .iqraStyle(.finePrint, color: IQColor.textFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var isUnlocked: Bool {
        (store.unlockedUntil.map { $0 > Date() } ?? false) || store.goalMetToday
    }

    private func credit(confirmed: Bool = false) {
        let outcome = appModel.unlock.recordAyahRead(confirmed: confirmed)
        guard outcome.counted else {
            needsReadConfirmation = true
            return
        }
        store.advanceKhatmCursor()
        justRead = true
        revision += 1
        appModel.syncDailyProgress(
            context: modelContext,
            minutesDelta: store.ayahUnlockMinutes / 3
        )
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task {
            await loadAyah()
            try? await Task.sleep(for: .seconds(2))
            justRead = false
        }
    }

    private func load() async {
        if repository == nil { repository = try? BundledQuranRepository() }
        await loadAyah()
    }

    private func loadAyah() async {
        guard let repository else { return }
        ayah = try? repository.ayah(globalID: store.khatmCursor)
    }
}
