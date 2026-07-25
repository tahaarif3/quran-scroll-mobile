import SwiftUI
import IqraLockKit

/// Phase 0 scratch screen — every design-system component in one place.
struct ComponentGalleryView: View {
    @State private var selected = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("IqraLock")
                    .iqraStyle(.wordmark, color: IQColor.olive)
                HighlightedText("locks **distracting apps**", style: .h1)
                StarRating()
                LaurelBadge(title: "#1 Muslim Focus App", subtitle: "Ummah funded")
                OptionRow(title: "More than 8h", emoji: "📱", isSelected: selected) {
                    selected.toggle()
                }
                OptionRow(title: "Build a daily habit", emoji: "🌅", isSelected: false, mode: .multi) {}
                ProgressRing(progress: 0.6)
                    .frame(maxWidth: .infinity)
                StreakPill(days: 12)
                HStack {
                    LockedAppTile(label: "Instagram")
                    LockedAppTile(label: "TikTok")
                }
                ChunkyButton("Continue", kind: .primary) {}
                ChunkyButton("Secondary", kind: .secondary) {}
                ChunkyButton("Disabled", kind: .primary, enabled: false) {}
            }
            .padding(IQSpace.gutter)
        }
        .background(IQColor.welcomeRadial.ignoresSafeArea())
    }
}

#Preview {
    ComponentGalleryView()
}
