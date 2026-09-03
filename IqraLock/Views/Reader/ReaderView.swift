import SwiftUI
import SwiftData
import IqraLockKit
import UIKit

struct ReaderView: View {
    var showsBack: Bool = true

    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var positions: [ReadingPosition]
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Environment(\.scenePhase) private var scenePhase

    @State private var surahNumber: Int = 1
    @State private var ayahs: [Ayah] = []
    @State private var index: Int = 0
    @State private var surah: SurahMeta?
    @State private var textSize: CGFloat = 26
    @State private var readingStyle: ReadingStyleAnswer = .arabicTranslation
    @State private var showSettings = false
    @State private var showSurahList = false
    @State private var repository: BundledQuranRepository?
    @State private var surahs: [SurahMeta] = []
    @State private var justCredited = false
    @State private var pendingConfirmation: Int?
    @State private var lastSeenResumeID: Int = 0
    @State private var casualMode: Bool = false
    @State private var showBookmarkToast = false
    @State private var bookmarkToastLabel = ""
    @State private var programmaticIndex: Int?

    private let bottomBarHeight: CGFloat = 118
    private var profile: UserProfile? { profiles.first }
    private var goal: Int { profile?.dailyGoalPages ?? appModel.store.dailyGoalPages }
    private var pagesToday: Int { appModel.store.pagesReadToday }
    private var current: Ayah? { ayahs.indices.contains(index) ? ayahs[index] : nil }
    private var isBookmarkedHere: Bool {
        guard let current else { return false }
        return bookmarks.first.map {
            $0.surahNumber == current.surah && $0.ayahNumber == current.ayah
        } ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            modeBanner
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
                .onChange(of: index) { previous, newIndex in
                    handleIndexChange(from: previous, to: newIndex)
                }
            }
        }
        .background(IQColor.bgReader.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .top) {
            if showBookmarkToast {
                Text(bookmarkToastLabel)
                    .iqraStyle(.captionStrong, color: IQColor.textInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(IQColor.oliveTint)
                            .overlay(Capsule().stroke(IQColor.accentOlive.opacity(0.35), lineWidth: 1))
                    )
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showBookmarkToast)
        .sheet(isPresented: Binding(
            get: { pendingConfirmation != nil },
            set: { if !$0 { pendingConfirmation = nil } }
        )) {
            AyahReadConfirmationSheet(
                onConfirm: {
                    if let position = pendingConfirmation {
                        pendingConfirmation = nil
                        creditAyah(at: position, confirmed: true)
                    }
                },
                onCancel: { pendingConfirmation = nil }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showSurahList) {
            SurahListView(surahs: surahs, currentSurah: surahNumber) { jump(to: $0) }
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(
                textSize: $textSize,
                readingStyle: $readingStyle,
                onDismiss: { showSettings = false }
            )
        }
        .task { await load() }
        .onAppear {
            syncToOpenTargetIfNeeded()
            syncFromProfile()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { syncToOpenTargetIfNeeded() }
        }
        .onChange(of: textSize) { _, new in
            profile?.arabicTextSize = Double(new)
            try? modelContext.save()
        }
        .onChange(of: readingStyle) { _, new in
            profile?.readingStyleRaw = new.rawValue
            try? modelContext.save()
        }
        .onChange(of: casualMode) { _, new in
            appModel.store.casualReadingMode = new
        }
        .navigationBarHidden(true)
    }

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

            Button { setBookmarkHere() } label: {
                Image(systemName: isBookmarkedHere ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isBookmarkedHere ? IQColor.accentOlive : IQColor.brandGold)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isBookmarkedHere ? "Bookmarked here" : "Bookmark this ayah")

            Button { showSettings = true } label: {
                Text("Aa")
                    .font(.custom("Nunito-Bold", size: 17))
                    .foregroundStyle(IQColor.brandGold)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Reader settings")
        }
        .padding(.horizontal, 4)
        .background(IQColor.bgReader)
    }

    private var modeBanner: some View {
        HStack {
            Toggle(isOn: $casualMode) {
                Text(casualMode ? "Free read — won't affect Screen Time" : "Focus mode — reading unlocks apps")
                    .iqraStyle(.caption, color: casualMode ? IQColor.textMuted : IQColor.accentOlive)
            }
            .tint(IQColor.accentOlive)
        }
        .padding(.horizontal, IQSpace.gutter)
        .padding(.vertical, 8)
        .background(IQColor.savePill.opacity(0.5))
    }

    private var dailyProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(IQColor.trackReader)
                if !casualMode {
                    Rectangle()
                        .fill(IQColor.accentOlive)
                        .frame(width: geo.size.width * min(1, Double(pagesToday) / Double(max(goal, 1))))
                }
            }
        }
        .frame(height: 4)
    }

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

                if readingStyle == .translationFirst {
                    translation(ayah)
                    arabic(ayah)
                } else {
                    arabic(ayah)
                    if readingStyle != .arabicOnly { translation(ayah) }
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

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                stepButton("chevron.left", enabled: index > 0) { move(by: -1) }
                VStack(spacing: 1) {
                    Text("Ayah \(index + 1) of \(max(1, ayahs.count))")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                    Text(justCredited
                         ? "Counted · \(appModel.store.ayahsReadToday)/\(appModel.store.ayahsPerPage) to the next page"
                         : casualMode
                            ? "Free read — position only"
                            : "\(pagesToday)/\(goal) pages today · p.\(current?.page ?? 1)")
                        .iqraStyle(.finePrint, color: justCredited ? IQColor.accentOlive : IQColor.textFaint)
                }
                .frame(maxWidth: .infinity)
                stepButton("chevron.right", enabled: index < ayahs.count - 1) { move(by: 1) }
            }

            ChunkyButton(index < ayahs.count - 1 ? "Next ayah →" : "Next surah →", kind: .primary) {
                if index < ayahs.count - 1 {
                    move(by: 1)
                } else {
                    if index < ayahs.count {
                        creditAyah(at: index)
                    }
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
    }

    private func handleIndexChange(from previous: Int, to newIndex: Int) {
        if programmaticIndex == newIndex {
            programmaticIndex = nil
            return
        }
        programmaticIndex = nil
        if newIndex > previous {
            creditAyah(at: previous)
        } else {
            savePosition()
        }
    }

    private func move(by delta: Int) {
        let target = index + delta
        guard ayahs.indices.contains(target) else { return }
        withAnimation { index = target }
    }

    private func creditAyah(at position: Int, confirmed: Bool = false) {
        guard let ayah = ayahs.indices.contains(position) ? ayahs[position] : nil else { return }
        savePosition(for: ayah)

        if casualMode {
            return
        }

        let outcome = appModel.unlock.recordAyahRead(confirmed: confirmed)
        guard outcome.counted else {
            pendingConfirmation = position
            return
        }
        appModel.store.advanceKhatmCursor(toAyahID: ayah.id + 1)
        lastSeenResumeID = ReaderResume.resumeGlobalID(store: appModel.store)
        justCredited = true
        appModel.syncDailyProgress(
            context: modelContext,
            minutesDelta: appModel.store.ayahUnlockMinutes / 3
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await Task.sleep(for: .seconds(2))
            justCredited = false
        }
    }

    private func setBookmarkHere() {
        guard let ayah = current else { return }
        ReaderResume.setBookmark(
            ayah: ayah,
            bookmarks: bookmarks,
            positions: positions,
            context: modelContext,
            store: appModel.store
        )
        lastSeenResumeID = ayah.id
        bookmarkToastLabel = "Bookmarked · \(ayah.verseKey)"
        showBookmarkToast = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            showBookmarkToast = false
        }
    }

    private func jump(to target: SurahMeta) { jumpToSurah(target.number) }

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
        syncFromProfile()
        casualMode = appModel.store.casualReadingMode
        syncToOpenTarget()
    }

    private func syncFromProfile() {
        textSize = CGFloat(profile?.arabicTextSize ?? 26)
        readingStyle = profile?.readingStyle ?? .arabicTranslation
    }

    private func syncToOpenTarget() {
        guard let repository else { return }
        let target = try? ReaderResume.openAyah(
            bookmarks: bookmarks,
            store: appModel.store,
            repository: repository
        )
        let resolvedTarget = target ?? (try? repository.ayah(surah: 1, ayah: 1))
        guard let resolvedTarget else { return }
        lastSeenResumeID = resolvedTarget.id
        surahNumber = resolvedTarget.surah
        surah = try? repository.surah(number: resolvedTarget.surah)
        ayahs = (try? repository.ayahs(forSurah: resolvedTarget.surah)) ?? []
        let targetIndex = ayahs.firstIndex(where: { $0.id == resolvedTarget.id }) ?? 0
        if targetIndex != index {
            programmaticIndex = targetIndex
        }
        index = targetIndex
    }

    private func syncToOpenTargetIfNeeded() {
        guard let repository else { return }
        let targetID = (try? ReaderResume.openAyah(
            bookmarks: bookmarks,
            store: appModel.store,
            repository: repository
        ))?.id
        guard targetID != lastSeenResumeID else { return }
        syncToOpenTarget()
    }

    private func savePosition() {
        guard let ayah = current else { return }
        savePosition(for: ayah)
    }

    private func savePosition(for ayah: Ayah) {
        ReaderResume.save(ayah: ayah, store: appModel.store)
        ReaderResume.upsertReadingPosition(ayah: ayah, positions: positions, context: modelContext)
        lastSeenResumeID = ayah.id
    }

    private func arabicIndic(_ n: Int) -> String {
        let map: [Character: Character] = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩"
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }
}
