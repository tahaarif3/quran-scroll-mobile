import SwiftUI
import SwiftData
import IqraLockKit

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Query private var profiles: [UserProfile]
    @Query private var positions: [ReadingPosition]
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]
    @State private var ringProgress: Double = 0

    private var profile: UserProfile? { profiles.first }
    private var name: String { profile?.displayName ?? appModel.store.userDisplayName }
    private var goal: Int { profile?.dailyGoalPages ?? appModel.store.dailyGoalPages }
    private var pagesToday: Int { appModel.store.pagesReadToday }
    private var lockedCount: Int { appModel.screenTime.selectedAppCount }

    private var stats: HabitStats {
        HabitStatsCalculator.compute(
            records: records.map {
                .init(day: $0.day, pagesRead: $0.pagesRead, minutesRead: $0.minutesRead, goalMet: $0.goalMet)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    ayahCard
                    todayCard
                    if lockedCount > 0 && !appModel.store.goalMetToday && appModel.purchases.gate.canBlockApps {
                        Text("🔒 \(lockedCount) apps locked until you finish")
                            .iqraStyle(.bodyStrong, color: IQColor.olive)
                    } else if !appModel.purchases.gate.canBlockApps {
                        Text("Blocking is off — subscribe to shield apps.")
                            .iqraStyle(.caption, color: IQColor.textSecondary)
                    }
                }
                .padding(.horizontal, IQSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(IQColor.welcomeRadial.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                appModel.store.ensureCurrentDay()
                withAnimation(.easeOut(duration: 0.9)) {
                    ringProgress = goal > 0 ? Double(pagesToday) / Double(goal) : 0
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .iqraStyle(.caption, color: IQColor.textSecondary)
                Text(name)
                    .iqraStyle(.h1, color: IQColor.textPrimary)
            }
            Spacer()
            StreakPill(days: stats.streakDays)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var ayahCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ayah of the day")
                    .iqraStyle(.captionStrong, color: IQColor.olive)
                Text(ayahPreview.arabic)
                    .font(.custom("Amiri-Regular", size: 22))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(ayahPreview.english)
                    .iqraStyle(.body, color: IQColor.textSecondary)
                Text(ayahPreview.ref)
                    .iqraStyle(.caption, color: IQColor.textMuted)
            }
        }
    }

    private var ayahPreview: (arabic: String, english: String, ref: String) {
        // Fallback curated copy when repository isn't loaded in preview.
        let key = AyahOfTheDay.key()
        return (
            "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
            "For indeed, with hardship comes ease.",
            "Qur'an \(key)"
        )
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's reading")
                        .iqraStyle(.captionStrong, color: IQColor.textOnDark.opacity(0.8))
                    Text("\(pagesToday) of \(goal) pages")
                        .iqraStyle(.h2, color: IQColor.textOnDark)
                }
                Spacer()
                ProgressRing(progress: ringProgress, size: 88, track: .white.opacity(0.12), fill: IQColor.gold)
                    .overlay(
                        Text("\(Int((ringProgress * 100).rounded()))%")
                            .iqraStyle(.captionStrong, color: IQColor.gold)
                    )
            }
            NavigationLink {
                ReaderView()
            } label: {
                Text("Continue reading")
                    .font(IQFontStyle.button.font)
                    .foregroundStyle(IQColor.textOnGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                            .fill(IQColor.goldBright)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
    }
}
