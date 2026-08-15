import SwiftUI
import IqraLockKit
import UIKit

/// "How it works", played instead of explained.
///
/// One screen, three phases, roughly thirty seconds: tap a shielded app, read one short ayah,
/// watch the apps come back. Nothing is asked of the user until the loop has already happened
/// once. The persistent Continue stays put the whole time and carries the emphasis change, so
/// no new button ever appears.
struct OnboardingDemoView: View {
    /// Reported upward so the scaffold's Continue can go ghost → filled with the phase.
    @Binding var hasPlayed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case invitation, shield, release }

    @State private var phase: Phase = .invitation
    @State private var ayah: Ayah?
    @State private var litTiles: Set<Int> = []
    @State private var lightPass = false
    @State private var showCountdown = false
    @State private var showReadMore = false
    @State private var secondsRemaining: Int = 30 * 60
    @State private var ayahsRead = 0
    @State private var ringPulse = false
    @State private var promptNudge = false

    private let tiles = LockedAppTile.Brand.allCases
    private let success = UINotificationFeedbackGenerator()

    var body: some View {
        VStack(spacing: 18) {
            headline
            tileGrid
            phaseFooter
        }
        .task { await loadAyah() }
        .onAppear(perform: startIdleCues)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 6) {
            Text(phase == .release ? "Your apps are open." : "Here's how it works")
                .iqraStyle(.h1, color: IQColor.textInk)
                .multilineTextAlignment(.center)
            Text(phase == .release
                 ? "That's the whole loop. One ayah, thirty minutes."
                 : "Your apps stay shielded until you read.")
                .iqraStyle(.subtitle, color: IQColor.textMuted2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tiles

    /// In the shield phase the tiles shrink to a dimmed strip rather than disappearing, so the
    /// user never loses sight of the thing they are unlocking.
    private var tileGrid: some View {
        let compact = phase == .shield
        return HStack(spacing: compact ? 10 : 14) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, brand in
                tile(brand, index: index, compact: compact)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) { lightPassOverlay }
        .animation(motion, value: phase)
    }

    private func tile(_ brand: LockedAppTile.Brand, index: Int, compact: Bool) -> some View {
        let lit = litTiles.contains(index)
        let side: CGFloat = compact ? 44 : 66
        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 11 : 16, style: .continuous)
                    .fill(brand.color)
                    .frame(width: side, height: side)
                    .saturation(lit ? 1 : 0)
                    .opacity(lit ? 1 : 0.42)
                    .scaleEffect(lit ? 1 : 0.94)

                Image(systemName: lit ? "checkmark" : "lock.fill")
                    .font(.system(size: compact ? 13 : 18, weight: .bold))
                    .foregroundStyle(lit ? IQColor.goldBright : .white.opacity(0.9))
                    .scaleEffect(lit ? 1 : 0.7)
            }
            .overlay(
                // One tile wears a ring so the invitation needs no coach-mark overlay.
                RoundedRectangle(cornerRadius: compact ? 11 : 16, style: .continuous)
                    .strokeBorder(IQColor.goldBright, lineWidth: 3)
                    .opacity(index == 0 && phase == .invitation ? 1 : 0)
                    .scaleEffect(ringPulse && !reduceMotion ? 1.18 : 1)
                    .opacity(ringPulse && !reduceMotion ? 0 : 1)
            )
            if !compact {
                Text(brand.label)
                    .iqraStyle(.finePrint, color: IQColor.textMuted)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { beginShield() }
        .accessibilityAddTraits(phase == .invitation ? .isButton : [])
        .accessibilityLabel(lit ? "\(brand.label), open" : "\(brand.label), shielded")
    }

    /// A single soft pass, never looped — a room brightening rather than a slot machine.
    @ViewBuilder
    private var lightPassOverlay: some View {
        if lightPass && !reduceMotion {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, IQColor.goldBright.opacity(0.10), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: lightPass ? geo.size.width : -geo.size.width * 0.4)
                .animation(.easeInOut(duration: 0.38), value: lightPass)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Footers

    @ViewBuilder
    private var phaseFooter: some View {
        switch phase {
        case .invitation:
            VStack(spacing: 12) {
                promptPill
                disclaimer("Simulated shield. IqraLock hasn't asked for any permissions yet.")
            }
        case .shield:
            VStack(spacing: 12) {
                ayahCard
                disclaimer("Simulated shield. IqraLock hasn't asked for any permissions yet.")
            }
        case .release:
            releaseFooter
        }
    }

    private var promptPill: some View {
        Text("Tap an app to see what happens")
            .iqraStyle(.captionStrong, color: IQColor.textOnDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(IQColor.bgDark))
            .offset(y: promptNudge && !reduceMotion ? 4 : 0)
            .animation(.easeOut(duration: 0.25), value: promptNudge)
    }

    /// IqraLock's own white card, deliberately not an imitation of the system Screen Time sheet.
    private var ayahCard: some View {
        VStack(spacing: 14) {
            Text("Instagram is shielded")
                .iqraStyle(.captionStrong, color: IQColor.textMuted)
            Text("Read this to open it")
                .iqraStyle(.h3, color: IQColor.textInk)

            if let ayah {
                Text(ayah.textUthmani)
                    .font(.custom("Amiri-Bold", size: 27))
                    // Arabic gets the widest measure on the screen and nothing beside it.
                    .lineSpacing(27)
                    .foregroundStyle(IQColor.textInk)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.vertical, 8)

                Rectangle().fill(IQColor.hairline).frame(height: 1)

                Text(ayah.translationEn)
                    .iqraStyle(.translation, color: IQColor.textMuted2)
                    .multilineTextAlignment(.center)
                Text(ayah.verseKey)
                    .iqraStyle(.caption, color: IQColor.textFaint)
            }

            ChunkyButton("I've read it") { release() }
            // The exchange rate is stated before the tap, not revealed after it.
            Text("One ayah opens them for 30 minutes")
                .iqraStyle(.finePrint, color: IQColor.textFaint)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .fill(IQColor.bgCard)
                .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
        )
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    private var releaseFooter: some View {
        VStack(spacing: 12) {
            if showCountdown {
                VStack(spacing: 2) {
                    Text(Self.clock(secondsRemaining))
                        .font(.custom("Nunito-Black", size: 30))
                        .monospacedDigit()
                        .foregroundStyle(IQColor.textInk)
                    Text("remaining")
                        .iqraStyle(.finePrint, color: IQColor.textFaint)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(IQColor.oliveTint))
                .transition(.opacity.combined(with: .offset(y: 8)))
            }

            if showReadMore {
                // A row, not a chunky button — the ask has to look as small as it is, and must
                // never outweigh Continue.
                Button(action: readAnother) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read one more")
                                .iqraStyle(.option, color: IQColor.textInk)
                            Text("Adds 30 minutes. Takes about 20 seconds.")
                                .iqraStyle(.finePrint, color: IQColor.textFaint)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(IQColor.brandPrimary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                            .fill(IQColor.bgCard)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .offset(y: 10)))
            }

            // Replaces the simulated-shield line in the same slot, so the last thing read before
            // advancing is the correction.
            disclaimer("You'll set your own goal next — anywhere from one ayah to ten pages a day. This demo used one.")
        }
    }

    private func disclaimer(_ text: String) -> some View {
        Text(text)
            .iqraStyle(.finePrint, color: IQColor.textFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Motion

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.78)
    }

    private func beginShield() {
        guard phase == .invitation else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(motion) { phase = .shield }
    }

    /// The 760ms release. One continuous letting-go rather than a set of things completing —
    /// colour returning to the tiles is the payoff, and everything else clears the way for it.
    private func release() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        success.prepare()
        ayahsRead += 1

        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) {
                phase = .release
                litTiles = Set(tiles.indices)
                showCountdown = true
                showReadMore = true
            }
            success.notificationOccurred(.success)
            hasPlayed = true
            startTicking()
            return
        }

        // 60–280ms — the card leaves upward, the direction the eye already travelled.
        withAnimation(.easeIn(duration: 0.22).delay(0.06)) { phase = .release }
        // 200–580ms — one light pass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { lightPass = true }
        // 240–520ms — colour returns in reading order on a 55ms stagger.
        for index in tiles.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24 + Double(index) * 0.055) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    _ = litTiles.insert(index)
                }
                // One haptic, on the first tile only. Four in a row reads as a win chime.
                if index == 0 { success.notificationOccurred(.success) }
            }
        }
        // 560–760ms — the aftermath.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            withAnimation(.easeOut(duration: 0.2)) { showCountdown = true }
            withAnimation(.easeOut(duration: 0.22)) { showReadMore = true }
            hasPlayed = true
            startTicking()
        }
    }

    /// Extension, visibly, rather than a reset — the number climbs instead of starting over.
    private func readAnother() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        ayahsRead += 1
        withAnimation(.easeOut(duration: 0.4)) { secondsRemaining += 30 * 60 }
        Task { await loadAyah() }
    }

    private func startTicking() {
        Task {
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
        }
    }

    /// Three pulses then rest. Nothing blinks continuously.
    private func startIdleCues() {
        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard phase == .invitation else { return }
            withAnimation(.easeOut(duration: 1.9).repeatCount(3, autoreverses: false)) {
                ringPulse = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            guard phase == .invitation else { return }
            promptNudge = true
        }
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Data

    private func loadAyah() async {
        // Ash-Sharh 94:6 — short, widely known, and it sets in two lines at 27pt.
        guard let repository = try? BundledQuranRepository() else {
            ayah = Ayah(
                id: 0, surah: 94, ayah: 6, verseKey: "Ash-Sharh 94:6",
                textUthmani: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
                translationEn: "Indeed, with hardship comes ease.",
                page: 596
            )
            return
        }
        ayah = try? repository.ayah(verseKey: "94:6")
    }
}
