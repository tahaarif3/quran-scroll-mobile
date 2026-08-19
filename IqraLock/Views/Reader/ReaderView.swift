import SwiftUI
import SwiftData
import IqraLockKit
import UIKit

/// One ayah at a time, swiped through the surah.
///
/// Reading and the shield now share a model: an ayah is the unit, the shared khatm cursor is the
/// position, and every ayah passed through counts the same wherever it was read. The previous
/// page-scrolling reader made those two different mechanics that had to be reconciled.
struct ReaderView: View {
    /// False when the reader *is* a tab root. `dismiss()` has nothing to dismiss there, so the
    /// chevron did nothing at all — it only means something for the pushed instance from Home.
    var showsBack: Bool = true

    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var positions: [ReadingPosition]

    @State private var surahNumber: Int = 1
    @State private var ayahs: [Ayah] = []
    @State private var index: Int = 0
    @State private var surah: SurahMeta?
    @State private var textSize: CGFloat = 26
    @State private var showSize = false
    @State private var showSurahList = false
    @State private var repository: BundledQuranRepository?
    @State private var surahs: [SurahMeta] = []
    @State private var justCredited = false
    /// Position of an ayah that arrived too quickly to count on its own. Non-nil presents the
    /// prompt; the answer either credits it or lets it go.
    @State private var pendingConfirmation: Int?

    private let bottomBarHeight: CGFloat = 118
    private var goal: Int { profiles.first?.dailyGoalPages ?? appModel.store.dailyGoalPages }
    private var style: ReadingStyleAnswer { profiles.first?.readingStyle ?? .arabicTranslation }
    private var pagesToday: Int { appModel.store.pagesReadToday }
    private var current: Ayah? { ayahs.indices.contains(index) ? ayahs[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            dailyProgressBar

            if ayahs.isEmpty {
                Spacer()
                ProgressView().tint(IQColor.accentOlive)
                Spacer()
            } else {
                TabView(selection: $index) {
                    ForEach(Array(ayahs.enumerated()), id: \.offset) { position, ayah in
                        ayahPage(ayah)
                            .tag(position)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Credit the ayah being left rather than the one arriving, so an ayah is only
                // counted once it has actually been sat with. recordAyah's minimum interval
                // then rejects anything swiped through faster than it could be read.
                .onChange(of: index) { previous, _ in
                    creditAyah(at: previous)
                }
            }
        }
        .background(IQColor.bgReader.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .confirmationDialog(
            "Did you read that ayah?",
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { pendingConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Yes, count it") {
                if let position = pendingConfirmation {
                    pendingConfirmation = nil
                    creditAyah(at: position, confirmed: true)
                }
            }
            Button("Not yet", role: .cancel) { pendingConfirmation = nil }
        } message: {
            Text("That was quick, so it hasn't been counted yet.")
        }
        .sheet(isPresented: $showSurahList) {
            SurahListView(surahs: surahs, currentSurah: surahNumber) { jump(to: $0) }
        }
        .sheet(isPresented: $showSize) {
            VStack(spacing: 16) {
                Text("Arabic text size").iqraStyle(.h3)
                Slider(value: $textSize, in: 20...40, step: 1)
                    .tint(IQColor.accentOlive)
                    .padding(.horizontal)
            }
            .padding()
            .presentationDetents([.height(180)])
        }
        .task { await load() }
        .navigationBarHidden(true)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            if showsBack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(IQColor.textFaint)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Button { showSurahList = true } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 5) {
                        Text(surah?.nameEnglish ?? "…")
                            .iqraStyle(.bodyStrong, color: IQColor.textInk)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(IQColor.textFaint)
                    }
                    Text(surah.map { "\($0.number) · \($0.nameTransliteration)" } ?? "")
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

    private var dailyProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(IQColor.trackReader)
                Rectangle()
                    .fill(IQColor.accentOlive)
                    .frame(width: geo.size.width * min(1, Double(pagesToday) / Double(max(goal, 1))))
            }
        }
        .frame(height: 4)
    }

    // MARK: - The ayah

    private func ayahPage(_ ayah: Ayah) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                if ayah.ayah == 1 {
                    Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ")
                        .font(.custom("Amiri-Regular", size: 22))
                        .foregroundStyle(IQColor.brandPrimary)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding(.top, 8)
                }

                Text(arabicIndic(ayah.ayah))
                    .font(.custom("Amiri-Bold", size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(IQColor.accentOlive))

                if style == .translationFirst {
                    translation(ayah)
                    arabic(ayah)
                } else {
                    arabic(ayah)
                    if style != .arabicOnly { translation(ayah) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.top, 18)
            .padding(.bottom, bottomBarHeight)
        }
    }

    private func arabic(_ ayah: Ayah) -> some View {
        Text(ayah.textUthmani)
            .font(.custom("Amiri-Bold", size: textSize))
            .lineSpacing(textSize * 1.15)
            .foregroundStyle(IQColor.textInk)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
    }

    private func translation(_ ayah: Ayah) -> some View {
        Text(ayah.translationEn)
            .iqraStyle(.translation, color: IQColor.textMuted2)
            .multilineTextAlignment(.center)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                stepButton("chevron.left", enabled: index > 0) { move(by: -1) }
                VStack(spacing: 1) {
                    Text("Ayah \(index + 1) of \(max(1, ayahs.count))")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                    Text(justCredited
                         ? "Counted · \(appModel.store.ayahsReadToday)/\(appModel.store.ayahsPerPage) to the next page"
                         : "\(pagesToday)/\(goal) pages today · p.\(current?.page ?? 1)")
                        .iqraStyle(.finePrint, color: justCredited ? IQColor.accentOlive : IQColor.textFaint)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.2), value: justCredited)
                stepButton("chevron.right", enabled: index < ayahs.count - 1) { move(by: 1) }
            }

            ChunkyButton(index < ayahs.count - 1 ? "Next ayah →" : "Next surah →", kind: .primary) {
                if index < ayahs.count - 1 {
                    move(by: 1)
                } else {
                    creditAyah(at: index)
                    jumpToSurah(surahNumber + 1)
                }
            }
        }
        .padding(.horizontal, IQSpace.gutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(minHeight: bottomBarHeight)
        .background(
            IQColor.bgReader.overlay(alignment: .top) {
                Rectangle().fill(IQColor.hairline).frame(height: 1)
            }
        )
    }

    private func stepButton(
        _ systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? IQColor.brandPrimary : IQColor.textFaint.opacity(0.4))
                .frame(width: 44, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(IQColor.savePill.opacity(enabled ? 1 : 0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous ayah" : "Next ayah")
    }

    // MARK: - Behaviour

    private func move(by delta: Int) {
        let target = index + delta
        guard ayahs.indices.contains(target) else { return }
        withAnimation { index = target }
    }

    /// Credits the ayah at `position` and moves the shared cursor past it.
    ///
    /// An ayah passed faster than it could plausibly be read is no longer dropped on the floor.
    /// Silently refusing to count it is indistinguishable from the feature being broken — and
    /// it was wrong as often as it was right, because someone re-reading a short ayah they know
    /// by heart is still reading. It asks instead.
    private func creditAyah(at position: Int, confirmed: Bool = false) {
        guard let ayah = ayahs.indices.contains(position) ? ayahs[position] : nil else { return }
        let outcome = appModel.unlock.recordAyahRead(confirmed: confirmed)
        guard outcome.counted else {
            pendingConfirmation = position
            return
        }
        appModel.store.advanceKhatmCursor(toAyahID: ayah.id + 1)
        savePosition()
        justCredited = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await Task.sleep(for: .seconds(2))
            justCredited = false
        }
    }

    private func jump(to target: SurahMeta) {
        jumpToSurah(target.number)
    }

    private func jumpToSurah(_ number: Int) {
        guard let repository, (1...114).contains(number) else { return }
        surahNumber = number
        surah = try? repository.surah(number: number)
        ayahs = (try? repository.ayahs(forSurah: number)) ?? []
        index = 0
        savePosition()
    }

    private func load() async {
        guard repository == nil else { return }
        guard let repo = try? BundledQuranRepository() else { return }
        repository = repo
        surahs = (try? repo.allSurahs()) ?? []
        textSize = profiles.first?.arabicTextSize ?? 26

        // Opens where the shared cursor is, so the reader and the shield agree about where the
        // user is in the mushaf. Previously this opened on a hardcoded Al-Mulk regardless.
        let cursor = appModel.store.khatmCursor
        let target = (try? repo.ayah(globalID: cursor)) ?? (try? repo.ayah(surah: 1, ayah: 1))
        guard let target else { return }
        surahNumber = target.surah
        surah = try? repo.surah(number: target.surah)
        ayahs = (try? repo.ayahs(forSurah: target.surah)) ?? []
        index = ayahs.firstIndex(where: { $0.id == target.id }) ?? 0
    }

    private func savePosition() {
        guard let ayah = current else { return }
        let pos = positions.first ?? {
            let p = ReadingPosition(
                surahNumber: ayah.surah,
                ayahNumber: ayah.ayah,
                pageNumber: ayah.page
            )
            modelContext.insert(p)
            return p
        }()
        pos.surahNumber = ayah.surah
        pos.ayahNumber = ayah.ayah
        pos.pageNumber = ayah.page
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
