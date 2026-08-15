import SwiftUI
import IqraLockKit

/// The dark card at the top of Home. A slot, not a card.
///
/// It holds a different thing in each of four states but never moves and never resizes, so the
/// user learns one place to look. Both hero layouts are pinned to a shared height for the same
/// reason — the ayah card below must not jump when the state changes.
///
/// The screen answers two questions in fixed positions: how long the apps are open, in the
/// largest type on the screen, and what one more ayah buys, in the same grammar every time.
/// There is never more than one headline figure.
struct HomeHeroCard: View {
    enum State: Equatable {
        case locked(closedApps: Int)
        case unlocked(until: Date)
        case partway(until: Date, ayahsRead: Int, goal: Int)
        case goalMet(ayahs: Int, pages: Int, sittings: Int)
    }

    let state: State
    let unlockMinutes: Int

    /// Pinned so the content below cannot shift between states.
    static let height: CGFloat = 232

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state {
            case .locked(let closedApps):
                lockedBody(closedApps: closedApps)
            case .unlocked(let until):
                unlockedBody(until: until, goal: nil)
            case .partway(let until, let read, let goal):
                unlockedBody(until: until, goal: (read, goal))
            case .goalMet(let ayahs, let pages, let sittings):
                goalMetBody(ayahs: ayahs, pages: pages, sittings: sittings)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
        .overlay(
            // The gold hairline is the app's only ornament: a completed thing, and nothing else.
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .strokeBorder(IQColor.accentGoldOnDark.opacity(isComplete ? 0.45 : 0), lineWidth: 1)
        )
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.4), value: isComplete)
    }

    private var isComplete: Bool {
        if case .goalMet = state { return true }
        return false
    }

    // MARK: - Locked

    private func lockedBody(closedApps: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Shielded")
                .font(.custom("Nunito-ExtraBold", size: 13))
                .tracking(0.8)
                .foregroundStyle(IQColor.accentGoldOnDark)
            Text("\(closedApps) apps are closed")
                .font(.custom("Nunito-Black", size: 26))
                .foregroundStyle(.white)
                .padding(.top, 4)

            hairline.padding(.vertical, 16)

            // The rate as an equation, not a sentence — and in the same slot a countdown will
            // later occupy, so there is one place to look.
            HStack(spacing: 10) {
                Text("1 ayah")
                    .font(.custom("Nunito-ExtraBold", size: 20))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(IQColor.accentGoldOnDark)
                Text("\(unlockMinutes) minutes")
                    .font(.custom("Nunito-ExtraBold", size: 20))
                    .foregroundStyle(IQColor.accentGoldOnDark)
            }
            Text("Read two and you have an hour. Time adds on, it never starts over.")
                .font(.custom("Nunito-SemiBold", size: 13))
                // Track, not Muted: muted grey on this brown measures 3.06:1 and fails AA.
                .foregroundStyle(IQColor.track)
                .padding(.top, 6)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Unlocked and partway

    private func unlockedBody(until: Date, goal: (read: Int, total: Int)?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Open")
                    .font(.custom("Nunito-ExtraBold", size: 13))
                    .tracking(0.8)
                    .foregroundStyle(IQColor.accentGoldOnDark)
                Text("until \(Self.clock.string(from: until))")
                    .font(.custom("Nunito-SemiBold", size: 13))
                    .foregroundStyle(IQColor.track)
            }

            // Continuous, not per-second: a TimelineView width rather than a ticking jump.
            TimelineView(.animation) { context in
                let remaining = max(0, until.timeIntervalSince(context.date))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Self.countdown(remaining))
                            .font(.custom("Nunito-Black", size: 52))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("left")
                            .font(.custom("Nunito-SemiBold", size: 15))
                            .foregroundStyle(IQColor.track)
                    }
                    drainingBar(remaining: remaining)
                }
                .padding(.top, 2)
            }

            hairline.padding(.vertical, 14)

            if let goal {
                goalLine(read: goal.read, total: goal.total)
            } else {
                offerLine(until: until)
            }
            Spacer(minLength: 0)
        }
    }

    /// The offer as a clock the user would have, not "+30 minutes" — so the decision needs no
    /// arithmetic. Always exactly one window ahead of the countdown.
    private func offerLine(until: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, until.timeIntervalSince(context.date))
            let underFive = remaining < 300
            HStack(spacing: 8) {
                Text("One more ayah")
                    .font(.custom("Nunito-SemiBold", size: underFive ? 20 : 17))
                    .foregroundStyle(IQColor.track)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(IQColor.accentGoldOnDark)
                Text(Self.countdown(remaining + Double(unlockMinutes * 60)))
                    .font(.custom("Nunito-ExtraBold", size: underFive ? 20 : 17))
                    .monospacedDigit()
                    .foregroundStyle(IQColor.accentGoldOnDark)
            }
            // The offer gets louder as time runs down; the warning never does.
            .animation(.easeInOut(duration: 2), value: underFive)
        }
    }

    /// Minutes above, goal beneath, split by the hairline — never side by side, which would make
    /// them look like alternatives rather than two things both true.
    private func goalLine(read: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's goal")
                    .font(.custom("Nunito-ExtraBold", size: 13))
                    .tracking(0.8)
                    .foregroundStyle(IQColor.accentOlive)
                Spacer()
                Text("\(max(0, total - read)) ayahs to go")
                    .font(.custom("Nunito-ExtraBold", size: 15))
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(IQColor.accentOlive)
                        .frame(width: geo.size.width * min(1, Double(read) / Double(max(1, total))))
                }
            }
            .frame(height: 6)
            Text("\(read) of \(total) read. Finishing opens everything until tomorrow.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(IQColor.track)
        }
    }

    // MARK: - Goal met

    /// The reward is the absence of the clock.
    private func goalMetBody(ayahs: Int, pages: Int, sittings: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's goal met")
                .font(.custom("Nunito-ExtraBold", size: 13))
                .tracking(0.8)
                .foregroundStyle(IQColor.accentGoldOnDark)
            Text("Open until tomorrow")
                .font(.custom("Nunito-Black", size: 26))
                .foregroundStyle(.white)
                .padding(.top, 4)
            Text("\(ayahs) ayahs, \(pages == 1 ? "one page" : "\(pages) pages"), in \(Self.spelled(sittings)) sittings.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(IQColor.track)
                .padding(.top, 6)

            hairline.padding(.vertical, 16)

            Text("No countdown for the rest of today")
                .font(.custom("Nunito-SemiBold", size: 15))
                .foregroundStyle(IQColor.track)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pieces

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }

    private func drainingBar(remaining: TimeInterval) -> some View {
        let total = Double(unlockMinutes * 60)
        let fraction = total > 0 ? min(1, max(0, remaining / total)) : 0
        // Under five minutes the bar cools toward grey. Nothing turns red, nothing pulses.
        let colour = remaining < 300 ? IQColor.textMuted : IQColor.accentGoldOnDark
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(colour).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 2), value: remaining < 300)
    }

    // MARK: - Formatting

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Tabular by construction: the field reserves its width so the hour digit appearing cannot
    /// reflow the layout.
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        return n < words.count ? words[n] : "\(n)"
    }
}
