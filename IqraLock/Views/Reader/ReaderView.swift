import SwiftUI
import SwiftData
import IqraLockKit

struct ReaderView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var positions: [ReadingPosition]

    @State private var surahNumber: Int = 67
    @State private var pageNumber: Int = 562
    @State private var ayahs: [Ayah] = []
    @State private var surah: SurahMeta?
    @State private var textSize: CGFloat = 26
    @State private var showSize = false
    @State private var encouragement = "Keep going — every page counts."
    @State private var repository: BundledQuranRepository?

    private let unlock = UnlockCoordinator()
    private let bottomBarHeight: CGFloat = 110

    private var goal: Int { profiles.first?.dailyGoalPages ?? appModel.store.dailyGoalPages }
    private var style: ReadingStyleAnswer { profiles.first?.readingStyle ?? .arabicTranslation }
    private var pagesToday: Int { appModel.store.pagesReadToday }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar
            ScrollView {
                LazyVStack(spacing: 0) {
                    Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ")
                        .font(.custom("Amiri-Regular", size: 28))
                        .foregroundStyle(IQColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .environment(\.layoutDirection, .rightToLeft)

                    ForEach(ayahs) { ayah in
                        ayahBlock(ayah)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, bottomBarHeight + 24)
            }
            .background(IQColor.bgReader)
        }
        .background(IQColor.bgReader.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showSize) {
            sizeSheet
                .presentationDetents([.height(180)])
        }
        .task { await load() }
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        HStack {
            // Embedded in tab — show title; back only when pushed
            VStack(spacing: 2) {
                Text(surah?.nameEnglish ?? "Al-Mulk")
                    .iqraStyle(.bodyStrong)
                Text(surah?.subtitle ?? "67 · The Sovereignty")
                    .iqraStyle(.caption, color: IQColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            Button {
                showSize = true
            } label: {
                Text("Aa")
                    .iqraStyle(.bodyStrong, color: IQColor.olive)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Text size")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(IQColor.bgReader)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(IQColor.bgReaderBar)
                Rectangle()
                    .fill(IQColor.olive)
                    .frame(width: geo.size.width * min(1, Double(pagesToday) / Double(max(goal, 1))))
            }
        }
        .frame(height: 4)
    }

    private func ayahBlock(_ ayah: Ayah) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ayah.textUthmani)
                    .font(.custom("Amiri-Regular", size: textSize))
                    .lineSpacing(textSize * 1.1)
                    .foregroundStyle(IQColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)

                Text(arabicIndic(ayah.ayah))
                    .font(.custom("Amiri-Regular", size: 13))
                    .foregroundStyle(IQColor.olive)
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(IQColor.olive, lineWidth: 1.2))
            }

            if style != .arabicOnly {
                if style == .arabicTransliteration || style == .allThree, let t = ayah.transliteration {
                    Text(t)
                        .iqraStyle(.caption, color: IQColor.textSecondary)
                        .italic()
                }
                if style == .arabicTranslation || style == .allThree {
                    Text(ayah.translationEn)
                        .font(.custom("Nunito-Medium", size: 15))
                        .foregroundStyle(IQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle()
                .fill(IQColor.hairline)
                .frame(height: 1)
                .padding(.top, 8)
        }
        .padding(.vertical, 12)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Page \(pageNumber) of 604")
                    .iqraStyle(.captionStrong, color: IQColor.textPrimary)
                Spacer()
                Text(encouragement)
                    .iqraStyle(.caption, color: IQColor.textSecondary)
                    .lineLimit(1)
            }
            ChunkyButton("✓ Mark page as read", kind: .primary) {
                markPage()
            }
        }
        .padding(.horizontal, IQSpace.gutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(minHeight: bottomBarHeight)
        .background(IQColor.bgReader.opacity(0.98))
    }

    private var sizeSheet: some View {
        VStack(spacing: 16) {
            Text("Arabic text size").iqraStyle(.h3)
            Slider(value: $textSize, in: 20...36, step: 1)
                .tint(IQColor.olive)
                .padding(.horizontal)
        }
        .padding()
    }

    private func load() async {
        do {
            let repo = try BundledQuranRepository()
            repository = repo
            if let pos = positions.first {
                surahNumber = pos.surahNumber
                pageNumber = pos.pageNumber
            }
            surah = try repo.surah(number: surahNumber)
            let page = try repo.page(pageNumber)
            ayahs = page.ayahs
            textSize = profiles.first?.arabicTextSize ?? 26
        } catch {
            // Demo ayahs if DB missing in a partial build
            ayahs = [
                Ayah(id: 1, surah: 67, ayah: 1, verseKey: "67:1",
                     textUthmani: "تَبَارَكَ ٱلَّذِى بِيَدِهِ ٱلْمُلْكُ وَهُوَ عَلَىٰ كُلِّ شَىْءٍۢ قَدِيرٌ",
                     translationEn: "Blessed is He in whose hand is dominion, and He is over all things competent.",
                     page: 562)
            ]
            surah = SurahMeta(
                number: 67,
                nameArabic: "الملك",
                nameEnglish: "Al-Mulk",
                nameTransliteration: "The Sovereignty",
                ayahCount: 30,
                revelationPlace: "makkah"
            )
        }
    }

    private func markPage() {
        appModel.store.ensureCurrentDay()
        appModel.store.pagesReadToday += 1
        let day = Calendar.current.startOfDay(for: Date())
        // Upsert daily record
        let descriptor = FetchDescriptor<DailyRecord>()
        if let existing = try? modelContext.fetch(descriptor).first(where: {
            Calendar.current.isDate($0.day, inSameDayAs: day)
        }) {
            existing.pagesRead = appModel.store.pagesReadToday
            existing.minutesRead += 3
            existing.goalMet = appModel.store.goalMetToday
            existing.goalPages = goal
        } else {
            modelContext.insert(DailyRecord(
                day: day,
                pagesRead: appModel.store.pagesReadToday,
                minutesRead: 3,
                goalMet: appModel.store.goalMetToday,
                goalPages: goal
            ))
        }
        if let repo = repository, pageNumber < 604,
           let next = try? repo.page(pageNumber + 1) {
            pageNumber += 1
            ayahs = next.ayahs
            if let first = next.ayahs.first {
                surahNumber = first.surah
                surah = try? repo.surah(number: first.surah)
            }
        }
        let pos = positions.first ?? {
            let p = ReadingPosition(surahNumber: surahNumber, ayahNumber: ayahs.first?.ayah ?? 1, pageNumber: pageNumber)
            modelContext.insert(p)
            return p
        }()
        pos.surahNumber = surahNumber
        pos.ayahNumber = ayahs.first?.ayah ?? 1
        pos.pageNumber = pageNumber
        pos.updatedAt = Date()
        try? modelContext.save()
        _ = unlock.evaluateAfterPageMarked()
        encouragement = appModel.store.goalMetToday ? "Goal met — apps unlocked!" : "Beautiful. \(appModel.store.pagesRemaining) to go."
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func arabicIndic(_ n: Int) -> String {
        let map: [Character: Character] = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩"
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

import UIKit
