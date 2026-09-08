import SwiftUI
import SwiftData
import IqraLockKit

struct BookmarksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]

    let onSelect: (Bookmark) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No bookmarks yet",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark icon while reading to save an ayah here.")
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                dismiss()
                                onSelect(bookmark)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(IQColor.accentOlive)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(bookmark.note.isEmpty
                                             ? "\(bookmark.surahNumber):\(bookmark.ayahNumber)"
                                             : bookmark.note)
                                            .iqraStyle(.bodyStrong, color: IQColor.textInk)
                                        Text("Surah \(bookmark.surahNumber) · Ayah \(bookmark.ayahNumber)")
                                            .iqraStyle(.caption, color: IQColor.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(IQColor.textFaint)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Bookmark delete failed: \(error)")
            #endif
        }
    }
}
