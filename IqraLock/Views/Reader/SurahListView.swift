import SwiftUI
import IqraLockKit

/// Jump-to-surah list. Without this the reader could only move forward one page at a time from
/// wherever it happened to open, which for a Qur'an app is close to disqualifying.
struct SurahListView: View {
    let surahs: [SurahMeta]
    let currentSurah: Int
    var onSelect: (SurahMeta) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [SurahMeta] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return surahs }
        // A bare number is almost always a surah number rather than a name fragment.
        if let n = Int(q) { return surahs.filter { $0.number == n } }
        return surahs.filter {
            $0.nameEnglish.localizedCaseInsensitiveContains(q)
                || $0.nameTransliteration.localizedCaseInsensitiveContains(q)
                || $0.nameArabic.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { surah in
                Button {
                    onSelect(surah)
                    dismiss()
                } label: {
                    row(surah)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    surah.number == currentSurah ? IQColor.oliveTint : IQColor.bgReader
                )
            }
            .listStyle(.plain)
            .background(IQColor.bgReader)
            .searchable(text: $query, prompt: "Surah name or number")
            .navigationTitle("Surahs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(IQColor.brandPrimary)
                }
            }
        }
    }

    private func row(_ surah: SurahMeta) -> some View {
        HStack(spacing: 14) {
            Text("\(surah.number)")
                .font(.custom("Nunito-ExtraBold", size: 13))
                .foregroundStyle(IQColor.brandPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(IQColor.savePill))

            VStack(alignment: .leading, spacing: 2) {
                Text(surah.nameTransliteration)
                    .iqraStyle(.option, color: IQColor.textInk)
                Text("\(surah.nameEnglish) · \(surah.ayahCount) ayahs · \(surah.revelationPlace.capitalized)")
                    .iqraStyle(.caption, color: IQColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(surah.nameArabic)
                .font(.custom("Amiri-Bold", size: 19))
                .foregroundStyle(IQColor.brandPrimary)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
