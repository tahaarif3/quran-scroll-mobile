import SwiftUI
import SwiftData
import IqraLockKit

struct ReaderView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var positions: [ReadingPosition]

    @State private var surahNumber: Int = 67
    @State private var pageNumber: Int = 562
    @State private var ayahs: [Ayah] = []
    @State private var surah: SurahMeta?
    @State private var textSize: CGFloat = 26
    @State private var showSize = false
    @State private var encouragement = "Almost there!"
    @State private var repository: BundledQuranRepository?

    /// Resolved from `AppModel`, never constructed here. A stored `UnlockCoordinator()` ran at
    /// view-struct init — which `TabView` performs for every tab up front — and cascaded through
    /// defaulted initializers into `ManagedSettingsStore()`, crashing the moment the root view
    /// swapped after onboarding. It also bypassed the app's injected services, silently dropping
    /// unlock analytics and notifications.
    private var unlock: UnlockCoordinator { appModel.unlock }
    private let bottomBarHeight: CGFloat = 110
    private var goal: Int { profiles.first?.dailyGoalPages ?? appModel.store.dailyGoalPages }
    private var style: ReadingStyleAnswer { profiles.first?.readingStyle ?? .arabicTranslation }
    private var pagesToday: Int { appModel.store.pagesReadToday }
    private var pageOfGoal: Int { min(pagesToday + 1, goal) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(IQColor.trackReader)
                    Rectangle()
                        .fill(IQColor.accentOlive)
                        .frame(width: geo.size.width * min(1, Double(pagesToday) / Double(max(goal, 1))))
                }
            }
            .frame(height: 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ")
                        .font(.custom("Amiri-Regular", size: 24))
                        .foregroundStyle(IQColor.brandPrimary)
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
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showSize) {
            VStack(spacing: 16) {
                Text("Arabic text size").iqraStyle(.h3)
                Slider(value: $textSize, in: 20...36, step: 1).tint(IQColor.accentOlive).padding(.horizontal)
            }
            .padding()
            .presentationDetents([.height(180)])
        }
        .task { await load() }
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(IQColor.textFaint)
                    .frame(width: 44, height: 44)
            }
            VStack(spacing: 2) {
                Text(surah?.nameEnglish ?? "Al-Mulk")
                    .iqraStyle(.bodyStrong, color: IQColor.textInk)
                Text(surah.map { "\($0.number) · \($0.nameTransliteration)" } ?? "67 · The Sovereignty")
                    .iqraStyle(.caption, color: IQColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            Button { showSize = true } label: {
                Text("Aa")
                    .font(.custom("Nunito-Bold", size: 17))
                    .foregroundStyle(IQColor.brandGold)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Text size")
        }
        .padding(.horizontal, 4)
        .background(IQColor.bgReader)
    }

    private func ayahBlock(_ ayah: Ayah) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ayah.textUthmani)
                    .font(.custom("Amiri-Bold", size: textSize))
                    .lineSpacing(textSize * 1.1)
                    .foregroundStyle(IQColor.textInk)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)

                Text(arabicIndic(ayah.ayah))
                    .font(.custom("Amiri-Bold", size: 12))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(IQColor.accentOlive))
            }

            if style != .arabicOnly {
                if style == .translationFirst {
                    Text(ayah.translationEn)
                        .iqraStyle(.translation, color: IQColor.textMuted2)
                } else if style == .arabicTranslation || style == .arabicTransliteration {
                    Text(ayah.translationEn)
                        .iqraStyle(.translation, color: IQColor.textMuted2)
                }
            }

            Rectangle().fill(IQColor.hairline).frame(height: 1).padding(.top, 6)
        }
        .padding(.vertical, 12)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Page \(pageOfGoal) of \(goal)")
                    .iqraStyle(.caption, color: IQColor.textMuted)
                Spacer()
                Text(encouragement)
                    .iqraStyle(.captionStrong, color: IQColor.accentOlive)
            }
            ChunkyButton("✓ Mark page as read", kind: .primary) { markPage() }
        }
        .padding(.horizontal, IQSpace.gutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(minHeight: bottomBarHeight)
        .background(
            IQColor.bgReader
                .overlay(alignment: .top) {
                    Rectangle().fill(IQColor.hairline).frame(height: 1)
                }
        )
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
            ayahs = try repo.page(pageNumber).ayahs
            textSize = profiles.first?.arabicTextSize ?? 26
        } catch {
            ayahs = [
                Ayah(
                    id: 1, surah: 67, ayah: 1, verseKey: "67:1",
                    textUthmani: "تَبَارَكَ ٱلَّذِى بِيَدِهِ ٱلْمُلْكُ وَهُوَ عَلَىٰ كُلِّ شَىْءٍۢ قَدِيرٌ",
                    translationEn: "Blessed is He in whose hand is dominion, and He is over all things competent.",
                    page: 562
                )
            ]
            surah = SurahMeta(
                number: 67, nameArabic: "الملك", nameEnglish: "Al-Mulk",
                nameTransliteration: "The Sovereignty", ayahCount: 30, revelationPlace: "makkah"
            )
        }
    }

    private func markPage() {
        // Day-roll, increment and unlock evaluation are owned by the coordinator so they cannot
        // interleave. `now` is captured once and reused for the DailyRecord below, so the record
        // and the counter can never disagree about which day this page belongs to.
        let now = Date()
        let outcome = appModel.unlock.recordPageRead(now: now)
        let day = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<DailyRecord>()
        if let existing = try? modelContext.fetch(descriptor).first(where: {
            Calendar.current.isDate($0.day, inSameDayAs: day)
        }) {
            existing.pagesRead = outcome.pagesToday
            existing.minutesRead += 3
            existing.goalMet = outcome.goalMet
            existing.goalPages = goal
        } else {
            modelContext.insert(DailyRecord(
                day: day,
                pagesRead: outcome.pagesToday,
                minutesRead: 3,
                goalMet: outcome.goalMet,
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
        encouragement = outcome.goalMet ? "Goal met!" : "Almost there!"
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
