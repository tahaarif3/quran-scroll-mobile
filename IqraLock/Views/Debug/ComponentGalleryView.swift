import SwiftUI
import IqraLockKit

struct ComponentGalleryView: View {
    @State private var selected = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                IqraAppIcon(size: 96)
                Text("Welcome to").iqraStyle(.subtitle, color: IQColor.textMuted)
                Text("IqraLock").iqraStyle(.wordmark, color: IQColor.brandPrimary)
                HighlightedText("locks **distracting apps**", style: .h1)
                LaurelBadge()
                OptionRow(title: "More than 8h", isSelected: false) {}
                OptionRow(title: "More than 8h", isSelected: true) {}
                OptionRow(title: "Build a daily reading habit", icon: .book, isSelected: selected, mode: .multi) {
                    selected.toggle()
                }
                HStack {
                    ForEach(LockedAppTile.Brand.allCases, id: \.self) { b in
                        LockedAppTile(brand: b)
                    }
                }
                ChunkyButton("Continue →", kind: .primary) {}
                ChunkyButton("Disabled", kind: .primary, enabled: false) {}
                ChunkyButton("Read now to unlock →", kind: .gold) {}
            }
            .padding(IQSpace.gutter)
        }
        .background(IQColor.bgSand.ignoresSafeArea())
    }
}

#Preview { ComponentGalleryView() }
