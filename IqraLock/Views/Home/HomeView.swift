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

    /// "Ayah of the day" while shielded; once the user is buying time it becomes "Next ayah" and
    /// walks the mushaf forward from where they are, because in that state they are not browsing.
    private var ayahCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isUnlocked ? "NEXT AYAH" : "AYAH OF THE DAY")
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

    private func credit() {
        let outcome = appModel.unlock.recordAyahRead()
        guard outcome.counted else { return }
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
        // Follows the shared cursor once the user is earning time, so Home and the shield agree
        // about which ayah is next.
        ayah = isUnlocked || store.totalAyahsToday > 0
            ? try? repository.ayah(globalID: store.khatmCursor)
            : try? repository.ayah(verseKey: AyahOfTheDay.key())
    }
}
