import SwiftUI
import SwiftData
import IqraLockKit
import UIKit

/// Home answers two questions in fixed positions: how long the apps are open, and what one more
/// ayah buys. Everything below the hero card is the means of doing it.
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]

    @State private var ayah: Ayah?
    @State private var needsReadConfirmation = false
    @State private var repository: BundledQuranRepository?
    @State private var justRead = false
    /// Drives the hero's re-render when reading changes the state underneath it.
    @State private var revision = 0

    private var store: AppGroupStore { appModel.store }
    private var name: String { profiles.first?.displayName ?? store.userDisplayName }
    private var lockedCount: Int { appModel.screenTime.selectedAppCount }
    private var remainingAyahs: Int { max(0, store.dailyGoalAyahs - store.totalAyahsToday) }

    private var stats: HabitStats {
        HabitStatsCalculator.compute(
            records: records.map {
                .init(day: $0.day, pagesRead: $0.pagesRead, minutesRead: $0.minutesRead, goalMet: $0.goalMet)
            }
        )
    }

    /// Partway is an unlocked state that has come within reach of the goal — at that point the
    /// better offer is the goal itself, so the "one more ayah" line steps aside for it.
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
                    emergencyPassNote
                }
                .padding(.horizontal, IQSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
            // Re-read the App Group every time this tab comes forward. AppGroupStore is a plain
            // wrapper over UserDefaults with no observation, so changing "one ayah unlocks N
            // minutes" in You changed nothing here until the app was relaunched — the card went
            // on offering the old number, which is the one piece of copy that has to be true.
            // `revision` is the card's `.id`, so bumping it rebuilds against current values.
            .onAppear { revision += 1 }
            .confirmationDialog(
                "Did you read that ayah?",
                isPresented: $needsReadConfirmation,
                titleVisibility: .visible
            ) {
                Button("Yes, count it") { credit(confirmed: true) }
                Button("Not yet", role: .cancel) {}
            } message: {
                Text("That was quick, so it hasn't been counted yet.")
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

    // MARK: - Ayah

    /// A first-time reader has not left off anywhere, and telling them to continue would be a
    /// small lie on the very first screen.
    private var continueLabel: String {
        store.khatmCursor > 1 || store.totalAyahsToday > 0
            ? "CONTINUE WHERE YOU LEFT OFF"
            : "START HERE"
    }

    /// Where the user left off, always. The card walks the mushaf forward from the shared
    /// cursor rather than offering a detached ayah of the day.
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
                    .font(.custom("Amiri-Bold", size: 27))
                    .lineSpacing(27)
                    .foregroundStyle(IQColor.textInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)

                Text(ayah?.translationEn ?? "")
                    .iqraStyle(.translation, color: IQColor.textMuted2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                primaryAction
            }
        }
    }

    /// The price is on the button — which is how the exchange rate lands without a tutorial.
    @ViewBuilder
    private var primaryAction: some View {
        if store.goalMetToday {
            // Nothing left to sell, so the button steps down to a ghost.
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
            // Within reach, so the CTA offers the whole remainder with an honest time cost.
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

    /// Available, never inviting: plain fine print, no button, no chevron.
    private var emergencyPassNote: some View {
        Text("Locked out and it can't wait? An emergency pass gives 15 minutes. \(store.emergencyPassesRemaining) left this month.")
            .iqraStyle(.finePrint, color: IQColor.textFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Behaviour

    private var isUnlocked: Bool {
        (store.unlockedUntil.map { $0 > Date() } ?? false) || store.goalMetToday
    }

    /// Asks rather than silently refusing when an ayah arrives faster than the minimum gap —
    /// a tap that does nothing and says nothing is indistinguishable from a broken button.
    private func credit(confirmed: Bool = false) {
        let outcome = appModel.unlock.recordAyahRead(confirmed: confirmed)
        guard outcome.counted else {
            needsReadConfirmation = true
            return
        }
        store.advanceKhatmCursor()
        justRead = true
        revision += 1
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
        // Always the shared cursor — the next ayah in the mushaf, wherever the user actually
        // stopped. "Ayah of the day" used to take its place until the first read of the day,
        // which meant the card offered an ayah from somewhere else entirely, and reading it
        // moved a cursor pointing at a different place. Home, the reader and the shield now all
        // read from one position, so picking up is picking up.
        ayah = try? repository.ayah(globalID: store.khatmCursor)
    }
}
