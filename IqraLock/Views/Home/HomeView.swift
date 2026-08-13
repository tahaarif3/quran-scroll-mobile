import SwiftUI
import SwiftData
import IqraLockKit

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]
    @State private var ringProgress: Double = 0
    @State private var dailyAyah: Ayah?
    @State private var ayahCredited = false

    private var name: String { profiles.first?.displayName ?? appModel.store.userDisplayName }
    private var goal: Int { profiles.first?.dailyGoalPages ?? appModel.store.dailyGoalPages }
    private var pagesToday: Int { appModel.store.pagesReadToday }
    private var lockedCount: Int { appModel.screenTime.selectedAppCount }
    private var remaining: Int { max(0, goal - pagesToday) }

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
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ayahCard
                    todayCard
                    NavigationLink {
                        ReaderView()
                    } label: {
                        Text("Continue reading →")
                            .font(IQFontStyle.button.font)
                            .foregroundStyle(IQColor.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: IQSpace.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: IQRadius.button, style: .continuous)
                                    .fill(IQColor.brandPrimaryShadow)
                                    .offset(y: IQShadow.chunkyOffset)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: IQRadius.button, style: .continuous)
                                    .fill(IQColor.brandPrimary)
                            )
                    }
                    .buttonStyle(.plain)

                    if lockedCount > 0 && !appModel.store.goalMetToday {
                        HStack(spacing: 6) {
                            Spacer()
                            IQIconView(.lock, size: 16)
                            Text("\(lockedCount) apps locked until you finish")
                                .iqraStyle(.captionStrong, color: IQColor.textMuted2)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, IQSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
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

    private var ayahCard: some View {
        SectionCard {
            VStack(spacing: 12) {
                HStack {
                    Text("AYAH OF THE DAY")
                        .font(.custom("Nunito-ExtraBold", size: 11))
                        .tracking(0.8)
                        .foregroundStyle(IQColor.accentOlive)
                    Spacer()
                    IQIconView(.bookmark, size: 20)
                }
                Text(dailyAyah?.textUthmani ?? "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا")
                    .font(.custom("Amiri-Bold", size: 27))
                    .foregroundStyle(IQColor.textInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(dailyAyah?.translationEn ?? "Indeed, with hardship comes ease.")
                    .iqraStyle(.translation, color: IQColor.textMuted2)
                    .multilineTextAlignment(.center)
                Text(dailyAyah?.verseKey ?? "Ash-Sharh 94:6")
                    .iqraStyle(.captionStrong, color: IQColor.textMuted2)

                // One ayah, there the moment the app opens, crediting real progress. The
                // smallest step forward the app offers — small enough to always say yes to.
                if ayahCredited {
                    Text("Counted · \(appModel.store.ayahsReadToday)/\(appModel.store.ayahsPerPage) toward your next page")
                        .iqraStyle(.caption, color: IQColor.accentOlive)
                        .padding(.top, 2)
                } else {
                    ChunkyButton("✓ I've read it", kind: .secondary) {
                        guard appModel.unlock.recordAyahRead().counted else { return }
                        ayahCredited = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .padding(.top, 2)
                }

                Button {
                    appModel.showReader = true
                } label: {
                    Text("Read more →")
                        .iqraStyle(.captionStrong, color: IQColor.brandPrimary)
                        .frame(minHeight: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .task { await loadDailyAyah() }
    }

    private func loadDailyAyah() async {
        guard dailyAyah == nil, let repository = try? BundledQuranRepository() else { return }
        dailyAyah = try? repository.ayah(verseKey: AyahOfTheDay.key())
    }

    private var todayCard: some View {
        HStack(spacing: 16) {
            ProgressRing(progress: ringProgress, lineWidth: 9, size: 84)
                .overlay(
                    Text("\(pagesToday)/\(goal)")
                        .font(.custom("Nunito-ExtraBold", size: 18))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's reading")
                    .font(.custom("Nunito-ExtraBold", size: 18))
                    .foregroundStyle(.white)
                Text(remaining == 0
                     ? "Goal met — apps unlocked"
                     : "\(remaining) pages left to unlock your apps")
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
    }
}
