import SwiftUI
import SwiftData
import IqraLockKit

struct ProgressViewScreen: View {
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]

    private var stats: HabitStats {
        HabitStatsCalculator.compute(
            records: records.map {
                .init(day: $0.day, pagesRead: $0.pagesRead, minutesRead: $0.minutesRead, goalMet: $0.goalMet)
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progress")
                    .iqraStyle(.h1)
                    .padding(.top, 8)

                streakCard

                HStack(spacing: 12) {
                    statCard(title: "Pages", value: "\(stats.pagesReadTotal)")
                    statCard(title: "Surahs", value: "\(stats.surahsCompleted)")
                    statCard(title: "Reclaimed", value: stats.hoursReclaimedLabel)
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Minutes read · last 7 days")
                            .iqraStyle(.bodyStrong)
                        barChart
                    }
                }
            }
            .padding(.horizontal, IQSpace.gutter)
            .padding(.bottom, 28)
        }
        .background(IQColor.welcomeRadial.ignoresSafeArea())
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("🔥")
                    .font(.system(size: 36))
                Text("\(stats.streakDays)")
                    .font(.custom("Nunito-Bold", size: 52))
                    .foregroundStyle(IQColor.textOnDark)
                Text("day streak")
                    .iqraStyle(.body, color: IQColor.textOnDark.opacity(0.8))
            }
            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    Circle()
                        .fill(stats.weekCompletion[i] ? IQColor.goldBright : Color.white.opacity(0.15))
                        .frame(width: 12, height: 12)
                        .accessibilityLabel(stats.weekCompletion[i] ? "Day \(i + 1) complete" : "Day \(i + 1) incomplete")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).iqraStyle(.caption, color: IQColor.textSecondary)
            Text(value).iqraStyle(.stat, color: IQColor.olive)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
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
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(value > 0 ? IQColor.olive : IQColor.chartNeutral)
                        .frame(height: height)
                    Text(dayLabel(i))
                        .iqraStyle(.caption, color: IQColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(dayLabel(i)): \(value) minutes")
            }
        }
        .frame(height: 130, alignment: .bottom)
    }

    private func dayLabel(_ index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        // Map last-7 window ending today onto weekday letters approximately
        return days[index % 7]
    }
}
