import SwiftUI
import IqraLockKit

/// The "how it works" step, played rather than described.
///
/// Tap a locked app, meet the shield, read one real ayah, watch the apps come back. Roughly
/// thirty seconds, and it replaces the static explainer rather than adding a step to a flow
/// that is already long.
///
/// It also self-selects. Someone who won't tap "I've read it" during a thirty-second demo was
/// never going to read pages daily — losing them here is better than losing them after they pay.
struct OnboardingDemoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Short, widely known, and already in the curated ayah-of-the-day list. Length matters:
    /// a long ayah turns a demo into homework.
    private static let demoVerseKeys = ["94:6", "2:152", "13:28"]

    private enum Phase {
        case locked
        case shield
        case unlocked
    }

    @State private var phase: Phase = .locked
    @State private var ayah: Ayah?
    @State private var ayahIndex = 0
    @State private var ayahsRead = 0
    @State private var repository: BundledQuranRepository?

    var body: some View {
        VStack(spacing: 20) {
            HighlightedText(
                phase == .unlocked
                    ? "That's it — **your apps are back**"
                    : "IqraLock **locks distracting apps** until…",
                style: .h1,
                highlight: IQColor.brandPrimary,
                alignment: .center
            )

            appTiles

            switch phase {
            case .locked:
                prompt("Tap a locked app to see what happens")
            case .shield:
                ayahCard
            case .unlocked:
                unlockedFooter
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82),
            value: phase
        )
        .task { await loadAyah() }
    }

    // MARK: - Pieces

    private var appTiles: some View {
        HStack(spacing: 8) {
            ForEach(LockedAppTile.Brand.allCases, id: \.self) { brand in
                LockedAppTile(brand: brand, dimmed: phase != .unlocked)
                    .onTapGesture {
                        guard phase == .locked else { return }
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        phase = .shield
                    }
            }
        }
        // The whole row is the target, not just one tile — a demo that only responds to
        // Instagram reads as broken when someone taps TikTok.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(phase == .unlocked ? "Apps unlocked" : "Four locked apps")
        .accessibilityAddTraits(phase == .locked ? .isButton : [])
    }

    private var ayahCard: some View {
        VStack(spacing: 14) {
            if let ayah {
                Text(ayah.textUthmani)
                    .font(.custom("Amiri-Bold", size: 22))
                    .lineSpacing(10)
                    .foregroundStyle(IQColor.textInk)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)

                Text("\"\(ayah.translationEn)\"")
                    .iqraStyle(.body, color: IQColor.textMuted2)
                    .multilineTextAlignment(.center)

                Text(ayah.verseKey)
                    .iqraStyle(.caption, color: IQColor.textFaint)
            } else {
                ProgressView().tint(IQColor.accentOlive)
            }

            ChunkyButton("✓ I've read it", kind: .primary) {
                ayahsRead += 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                phase = .unlocked
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .fill(IQColor.bgCard)
                .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
        )
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    private var unlockedFooter: some View {
        VStack(spacing: 10) {
            Text(ayahsRead == 1
                 ? "One ayah. That's all it took."
                 : "\(ayahsRead) ayahs read.")
                .iqraStyle(.bodyStrong, color: IQColor.textInk)

            // The whole point of the mechanic: forward movement is always available, and always
            // small enough to say yes to.
            Button {
                nextAyah()
                phase = .shield
            } label: {
                Text("Read one more →")
                    .iqraStyle(.captionStrong, color: IQColor.brandPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Honesty guard. If the demo unlocks on one ayah but the app asks for pages, that
            // is a bait-and-switch and it churns people in the first week.
            Text("In the app you'll set your own daily goal — and every ayah counts toward it.")
                .iqraStyle(.finePrint, color: IQColor.textFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .transition(.opacity)
    }

    private func prompt(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(IQColor.brandGold)
            Text(text)
                .iqraStyle(.captionStrong, color: IQColor.textMuted2)
        }
        .transition(.opacity)
    }

    // MARK: - Data

    private func loadAyah() async {
        guard repository == nil else { return }
        repository = try? BundledQuranRepository()
        setAyah()
    }

    private func nextAyah() {
        ayahIndex = (ayahIndex + 1) % Self.demoVerseKeys.count
        setAyah()
    }

    private func setAyah() {
        let key = Self.demoVerseKeys[ayahIndex]
        // Falls back to the bundled text of 94:6 so the demo still reads correctly if the
        // database somehow fails to open — a blank card here would be the worst possible first
        // impression.
        ayah = (try? repository?.ayah(verseKey: key)) ?? Ayah(
            id: 0, surah: 94, ayah: 6, verseKey: "Ash-Sharh 94:6",
            textUthmani: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
            translationEn: "Indeed, with hardship comes ease.",
            page: 596
        )
    }
}
