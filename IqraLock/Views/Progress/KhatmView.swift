import SwiftUI
import SwiftData
import IqraLockKit

/// Progress through the whole Qur'an.
///
/// The structure is constant across every state — where you are, how far the next small ending
/// is, and when this khatm finishes at your own pace — and only the emphasis moves. 6,236 is
/// never the headline; the page you are on is. A streak can be broken and ends in deletion; a
/// khatm can only be finished.
struct KhatmView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \DailyRecord.day, order: .reverse) private var records: [DailyRecord]

    @State private var repository: BundledQuranRepository?
    @State private var currentPage: Int?
    @State private var currentSurah: SurahMeta?
    @State private var remainingSurahs: Int?

    private var store: AppGroupStore { appModel.store }
    private var cursor: Int { store.khatmCursor }
    private var progress: Double { store.khatmProgress }
    private var pagesLeft: Int { max(0, AppGroupStore.pagesInMushaf - (currentPage ?? 1) + 1) }
    private var juz: Int { Juz.number(forAyahID: cursor) }

    /// The user's own last seven days, never a cohort average — a pace someone else set is not
    /// information about you.
    private var ayahsPerDay: Double {
        let recent = records.prefix(7)
        guard !recent.isEmpty else { return 0 }
        let ayahs = recent.reduce(0) { $0 + $1.pagesRead * store.ayahsPerPage }
        return Double(ayahs) / Double(recent.count)
    }

    private var daysRemaining: Int? {
        guard ayahsPerDay > 0 else { return nil }
        return Int((Double(store.ayahsToKhatm) / ayahsPerDay).rounded(.up))
    }

    /// Emphasis moves with distance to the end, not with a mode switch.
    private var isNearlyFinished: Bool { progress >= 0.97 }
    private var hasStarted: Bool { progress >= 0.05 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headline
                positionCard
                if hasStarted { juzStrip }
                nextEndingCard
                if isNearlyFinished { finishCTA }
                if !store.khatmRecords.isEmpty { ledger }
            }
            .padding(.horizontal, IQSpace.gutter)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(IQColor.bgSand.ignoresSafeArea())
        .navigationTitle("Your khatm")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Headline

    /// Position while there is distance left; remainder once the end is in sight. The number that
    /// matters changes, so the headline changes with it.
    private var headline: some View {
        VStack(spacing: 4) {
            if isNearlyFinished {
                Text("\(pagesLeft) pages left")
                    .iqraStyle(.h1, color: IQColor.textInk)
            } else {
                Text("Page \(currentPage ?? 1)")
                    .iqraStyle(.h1, color: IQColor.textInk)
                Text("of 604 · juz \(juz)")
                    .iqraStyle(.subtitle, color: IQColor.textMuted2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Position

    private var positionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(IQColor.accentGoldOnDark)
                        .frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 8)

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f%%", progress * 100))
                    .font(.custom("Nunito-Black", size: 22))
                    .foregroundStyle(.white)
                Spacer()
                if let daysRemaining {
                    Text("about \(daysRemaining) days at your pace")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(IQColor.track)
                } else {
                    Text("pace appears after a few days")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(IQColor.track)
                }
            }

            // 6,236 stays on screen — hiding it would be the lie — but small, and never as the
            // headline.
            Text("\(store.ayahsIntoKhatm) of \(AppGroupStore.ayahsInMushaf) ayahs, in order")
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundStyle(IQColor.track)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
    }

    // MARK: - Juz strip

    /// Deliberately absent at the very start, where twenty-nine empty bars would only advertise
    /// how little has happened.
    private var juzStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIRTY JUZ")
                .font(.custom("Nunito-ExtraBold", size: 11))
                .tracking(0.8)
                .foregroundStyle(IQColor.accentOlive)
            HStack(spacing: 3) {
                ForEach(1...Juz.count, id: \.self) { index in
                    Capsule()
                        .fill(colour(forJuz: index))
                        .frame(height: 22)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .fill(IQColor.bgCard)
        )
    }

    private func colour(forJuz index: Int) -> Color {
        if index < juz { return IQColor.accentOlive }
        if index == juz { return IQColor.brandGold }
        return IQColor.track
    }

    // MARK: - The next small ending

    /// Thirty small endings, not one enormous one. This is the card the eye should land on
    /// second — a boundary close enough to be worth aiming at.
    private var nextEndingCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                if isNearlyFinished {
                    Text("What's left")
                        .iqraStyle(.captionStrong, color: IQColor.accentOlive)
                    Text(remainingSurahsLine)
                        .iqraStyle(.bodyStrong, color: IQColor.textInk)
                    Text("The duʿāʾ will be waiting at the end.")
                        .iqraStyle(.caption, color: IQColor.textMuted2)
                } else {
                    Text("NEXT ENDING")
                        .font(.custom("Nunito-ExtraBold", size: 11))
                        .tracking(0.8)
                        .foregroundStyle(IQColor.accentOlive)
                    Text(juz < Juz.count ? "Juz \(juz + 1)" : "The end of the mushaf")
                        .iqraStyle(.h3, color: IQColor.textInk)
                    Text("\(Juz.ayahsToNextBoundary(fromAyahID: cursor)) ayahs away")
                        .iqraStyle(.caption, color: IQColor.textMuted2)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(IQColor.track)
                            Capsule()
                                .fill(IQColor.accentOlive)
                                .frame(width: max(3, geo.size.width * Juz.progress(atAyahID: cursor)))
                        }
                    }
                    .frame(height: 6)
                    .padding(.top, 2)
                }
            }
        }
    }

    private var remainingSurahsLine: String {
        guard let currentSurah, let remainingSurahs else { return "The last few surahs" }
        return "\(currentSurah.nameTransliteration) to An-Nās, \(remainingSurahs) surahs"
    }

    private var finishCTA: some View {
        ChunkyButton("Finish it") { appModel.showReader = true }
    }

    // MARK: - Ledger

    /// A dated ledger and a gold hairline. No badge, no confetti, no level.
    private var ledger: some View {
        let all = store.khatmRecords.reversed().map { $0 }
        // By the tenth the number speaks without emphasis, so the list collapses.
        let shown = all.count > 3 ? Array(all.prefix(3)) : all
        return VStack(alignment: .leading, spacing: 10) {
            Text(all.count == 1 ? "Your first khatm" : "\(all.count) khatms completed")
                .iqraStyle(.h3, color: IQColor.textInk)
            ForEach(shown) { record in
                HStack {
                    Text(Self.dateFormatter.string(from: record.completedAt))
                        .iqraStyle(.body, color: IQColor.textInk)
                    Spacer()
                    Text("\(record.elapsedDays) days")
                        .iqraStyle(.caption, color: IQColor.textMuted2)
                }
            }
            if all.count > shown.count {
                Text("See all \(all.count)")
                    .iqraStyle(.captionStrong, color: IQColor.brandPrimary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .strokeBorder(IQColor.accentGoldOnDark.opacity(0.45), lineWidth: 1)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    // MARK: - Data

    private func load() async {
        if repository == nil { repository = try? BundledQuranRepository() }
        guard let repository else { return }
        let ayah = try? repository.ayah(globalID: cursor)
        currentPage = ayah?.page
        if let surah = ayah?.surah {
            currentSurah = try? repository.surah(number: surah)
            remainingSurahs = 114 - surah + 1
        }
    }
}
