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
    @State private var surahs: [SurahMeta] = []
    @State private var showSurahList = false
    @State private var visibleAyahID: Int?

    /// Position within the current page, 1-based, for the "ayah 7 of 15" readout.
    private var ayahIndexOnPage: Int {
        guard let visibleAyahID,
              let index = ayahs.firstIndex(where: { $0.id == visibleAyahID }) else { return 1 }
        return index + 1
    }

    private var currentAyah: Ayah? {
        guard let visibleAyahID else { return ayahs.first }
        return ayahs.first { $0.id == visibleAyahID } ?? ayahs.first
    }

    /// How far through the page's own ayahs the reader has scrolled.
    ///
    /// Deliberately not credited as loose ayahs: a mushaf page holds anywhere from three to
    /// twenty ayahs, so crediting each one at the flat `ayahsPerPage` rate would make a short
    /// page worth a fraction of a long one. Sequential reading credits whole pages; the
    /// ayah-at-a-time rate is for loose ayahs off the shield.
    private var pageScrollProgress: Double {
        guard !ayahs.isEmpty else { return 0 }
        return Double(ayahIndexOnPage) / Double(ayahs.count)
    }

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
                            .id(ayah.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.bottom, bottomBarHeight + 24)
            }
            .background(IQColor.bgReader)
            // Tracks which ayah is at the top of the viewport, so the saved position is where
            // the reader actually is rather than where the page starts.
            .scrollPosition(id: $visibleAyahID, anchor: .top)
            .onChange(of: visibleAyahID) { _, _ in savePosition() }
        }
        .background(IQColor.bgReader.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showSurahList) {
            SurahListView(surahs: surahs, currentSurah: surahNumber) { jump(to: $0) }
        }
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
            Button {
                showSurahList = true
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 5) {
                        Text(surah?.nameEnglish ?? "Al-Mulk")
                            .iqraStyle(.bodyStrong, color: IQColor.textInk)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(IQColor.textFaint)
                    }
                    Text(surah.map { "\($0.number) · \($0.nameTransliteration)" } ?? "67 · The Sovereignty")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose surah")
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
            // "Translation first" now actually puts it first. It previously rendered
            // identically to "Arabic + translation", so the setting did nothing.
            if style == .translationFirst {
                translationLine(ayah)
                arabicLine(ayah)
            } else {
                arabicLine(ayah)
                if style != .arabicOnly {
                    translationLine(ayah)
                }
            }

            Rectangle().fill(IQColor.hairline).frame(height: 1).padding(.top, 6)
        }
        .padding(.vertical, 12)
    }

    private func arabicLine(_ ayah: Ayah) -> some View {
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
    }

    private func translationLine(_ ayah: Ayah) -> some View {
        Text(ayah.translationEn)
            .iqraStyle(.translation, color: IQColor.textMuted2)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Paging is separate from the daily goal: moving around the mushaf should not
                // count pages as read, only the CTA does.
                pageStepButton(systemName: "chevron.left", enabled: pageNumber > 1) {
                    goToPage(pageNumber - 1)
                }
                VStack(spacing: 1) {
                    Text("Page \(pageOfGoal) of \(goal)")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                    Text("Mushaf p.\(pageNumber) · ayah \(ayahIndexOnPage) of \(max(1, ayahs.count))")
                        .iqraStyle(.finePrint, color: IQColor.textFaint)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    // Fills as the page is scrolled, so the page is visibly being worked
                    // through rather than jumping from nothing to done at the button press.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(IQColor.trackReader)
                            Capsule()
                                .fill(IQColor.accentOlive.opacity(0.7))
                                .frame(width: geo.size.width * pageScrollProgress)
                        }
                    }
                    .frame(height: 3)
                    .offset(y: 8)
                    .animation(.easeOut(duration: 0.25), value: pageScrollProgress)
                }
                pageStepButton(systemName: "chevron.right", enabled: pageNumber < 604) {
                    goToPage(pageNumber + 1)
                }
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

    private func pageStepButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? IQColor.brandPrimary : IQColor.textFaint.opacity(0.4))
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(IQColor.savePill.opacity(enabled ? 1 : 0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous page" : "Next page")
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
            // Resume on the exact ayah, not the top of its page.
            let savedAyah = positions.first?.ayahNumber
            visibleAyahID = ayahs.first(where: { $0.ayah == savedAyah })?.id ?? ayahs.first?.id
            surahs = (try? repo.allSurahs()) ?? []
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
        goToPage(pageNumber + 1)
        encouragement = outcome.goalMet ? "Goal met!" : "Almost there!"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Moves to any mushaf page and keeps the surah header and saved position in step. Marking a
    /// page read, jumping to a surah and paging backwards all route through here so they cannot
    /// disagree about where the reader is.
    private func goToPage(_ target: Int) {
        guard let repo = repository,
              target >= 1, target <= 604,
              let page = try? repo.page(target) else { return }
        pageNumber = target
        ayahs = page.ayahs
        // Start a new page at its first ayah rather than inheriting the previous page's scroll
        // offset, which would otherwise leave the reader part-way down a page it just opened.
        visibleAyahID = page.ayahs.first?.id
        if let first = page.ayahs.first {
            surahNumber = first.surah
            surah = try? repo.surah(number: first.surah)
        }
        savePosition()
    }

    private func jump(to target: SurahMeta) {
        guard let repo = repository,
              let page = try? repo.pageNumber(surah: target.number, ayah: 1) else { return }
        goToPage(page)
        // goToPage resolves the surah from the page's first ayah, which can be the *previous*
        // surah when one ends partway down the page. The user asked for this one.
        surahNumber = target.number
        surah = target
        savePosition()
    }

    private func savePosition() {
        // The ayah actually on screen, not the first on the page — so reopening returns the
        // reader to where the user stopped rather than to the top of the page they were on.
        let ayahNumber = currentAyah?.ayah ?? ayahs.first?.ayah ?? 1
        let pos = positions.first ?? {
            let p = ReadingPosition(
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                pageNumber: pageNumber
            )
            modelContext.insert(p)
            return p
        }()
        pos.surahNumber = surahNumber
        pos.ayahNumber = ayahNumber
        pos.pageNumber = pageNumber
        pos.updatedAt = Date()
        try? modelContext.save()
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
