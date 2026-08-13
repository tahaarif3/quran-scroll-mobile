import SwiftUI
import SwiftData
import IqraLockKit

struct ProgressViewScreen: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]

    private var stats: HabitStats {
        HabitStatsCalculator.compute(
            records: records.map {
                .init(day: $0.day, pagesRead: $0.pagesRead, minutesRead: $0.minutesRead, goalMet: $0.goalMet)
            }
        )
    }

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your progress")
                    .iqraStyle(.h1)
                    .padding(.top, 8)

                khatmLink
                streakCard

                HStack(spacing: 12) {
                    statCard(value: "\(stats.pagesReadTotal)", label: "pages read")
                    statCard(value: stats.hoursReclaimedLabel, label: "reclaimed")
                    statCard(value: "\(stats.surahsCompleted)", label: "surahs")
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Minutes read · last 7 days")
                            .iqraStyle(.caption, color: IQColor.textMuted)
                        barChart
                    }
                }
            }
            .padding(.horizontal, IQSpace.gutter)
            .padding(.bottom, 28)
        }
        .background(IQColor.bgSand.ignoresSafeArea())
    }

    /// Above the streak on purpose. A streak measures consistency; a khatm measures the thing
    /// the consistency is for.
    private var khatmLink: some View {
        NavigationLink {
            KhatmView()
        } label: {
            SectionCard {
                HStack(spacing: 14) {
                    IQIconView(.book, size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your khatm")
                            .iqraStyle(.bodyStrong, color: IQColor.textInk)
                        Text("\(appModel.store.ayahsToKhatm) ayahs to finishing the Qur'an")
                            .iqraStyle(.caption, color: IQColor.textMuted2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IQColor.textFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var streakCard: some View {
        VStack(spacing: 14) {
            IQIconView(.flame, size: 40)
            Text("\(stats.streakDays)")
                .font(.custom("Nunito-Bold", size: 52))
                .foregroundStyle(.white)
            Text("day streak · keep it going")
                .iqraStyle(.body, color: .white.opacity(0.85))

            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    let labels = ["M", "T", "W", "T", "F", "S", "S"]
                    VStack(spacing: 6) {
                        Text(labels[i])
                            .font(.custom("Nunito-SemiBold", size: 11))
                            .foregroundStyle(IQColor.accentGoldOnDark.opacity(0.8))
                        ZStack {
                            Circle()
                                .fill(stats.weekCompletion[i]
                                      ? IQColor.accentGoldOnDark
                                      : Color.white.opacity(0.12))
                                .frame(width: 22, height: 22)
                            if stats.weekCompletion[i] {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(IQColor.bgDark)
                            }
                        }
                        .accessibilityLabel(stats.weekCompletion[i] ? "\(labels[i]) complete" : "\(labels[i]) incomplete")
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value).iqraStyle(.stat, color: IQColor.accentOlive)
            Text(label).iqraStyle(.caption, color: IQColor.textMuted)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .fill(Color.white)
                .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
        )
    }

    private var barChart: some View {
        let maxM = max(stats.minutesLast7Days.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                let value = stats.minutesLast7Days[i]
                let height = max(8, CGFloat(value) / CGFloat(maxM) * 100)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(value > 0 && (i == 3 || i == 6 || stats.weekCompletion[i])
                          ? IQColor.accentOlive
                          : IQColor.chartNeutral)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Day \(i + 1): \(value) minutes")
            }
        }
        .frame(height: 120, alignment: .bottom)
    }
}
