import SwiftUI
import IqraLockKit

/// Progress toward finishing the whole Qur'an.
///
/// A streak only ever continues — there is no completion, so there is no payoff, only eventual
/// failure. A khatm has an end, it carries real weight, and finishing one is something a person
/// tells other people about. It is also the frame no competitor can copy: five minutes after a
/// prayer doesn't ladder up to anything, and pages do.
struct KhatmView: View {
    @Environment(AppModel.self) private var appModel

    private var pagesInto: Int { appModel.store.pagesIntoKhatm }
    private var pagesLeft: Int { appModel.store.pagesToKhatm }
    private var progress: Double { appModel.store.khatmProgress }
    private var completed: Int { appModel.store.khatmCount }

    /// Days remaining at the pace they've actually set, not an average of everyone.
    private var projectedDays: Int {
        let perDay = max(1, appModel.store.dailyGoalPages)
        return Int((Double(pagesLeft) / Double(perDay)).rounded(.up))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                headline
                ringCard
                statsRow
                if completed > 0 { completedCard }
                paceNote
            }
            .padding(.horizontal, IQSpace.gutter)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(IQColor.bgSand.ignoresSafeArea())
        .navigationTitle("Your khatm")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(completed == 0 ? "Your first khatm" : "Khatm \(completed + 1)")
                .iqraStyle(.h2, color: IQColor.textInk)
            Text("\(pagesLeft) pages to go")
                .iqraStyle(.subtitle, color: IQColor.textMuted2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var ringCard: some View {
        VStack(spacing: 14) {
            ProgressRing(
                progress: progress,
                lineWidth: 14,
                size: 176,
                track: Color.white.opacity(0.14),
                fill: IQColor.accentGoldOnDark
            )
            .overlay(
                VStack(spacing: 2) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.custom("Nunito-Black", size: 34))
                        .foregroundStyle(.white)
                    Text("\(pagesInto) / \(AppGroupStore.pagesInMushaf)")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            )
            Text("pages of the mushaf read")
                .iqraStyle(.caption, color: .white.opacity(0.75))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                .fill(IQColor.bgDark)
        )
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("\(appModel.store.totalPagesRead)", "pages\nall time")
            statTile("\(projectedDays)", "days at\nyour pace")
            statTile("\(completed)", completed == 1 ? "khatm\ncompleted" : "khatms\ncompleted")
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Nunito-Black", size: 24))
                .foregroundStyle(IQColor.brandPrimary)
            Text(label)
                .iqraStyle(.caption, color: IQColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                .fill(IQColor.bgCard)
                .shadow(color: IQShadow.card.color, radius: IQShadow.card.radius, y: IQShadow.card.y)
        )
    }

    private var completedCard: some View {
        SectionCard {
            HStack(spacing: 14) {
                IQIconView(.star, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(completed == 1
                         ? "You've completed the Qur'an once"
                         : "You've completed the Qur'an \(completed) times")
                        .iqraStyle(.bodyStrong, color: IQColor.textInk)
                    Text("May Allah accept it from you.")
                        .iqraStyle(.caption, color: IQColor.textMuted2)
                }
            }
        }
    }

    private var paceNote: some View {
        Text("Every ayah counts. \(appModel.store.ayahsPerPage) ayahs make a page, whether you read them here or from the lock screen.")
            .iqraStyle(.caption, color: IQColor.textFaint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}
