import SwiftUI
import IqraLockKit

#if canImport(FamilyControls)
import FamilyControls

/// Real device app picker. Onboarding uses a mock list in Simulator.
struct FamilyActivityPickerScreen: View {
    @Binding var selection: FamilyActivitySelection
    var onSave: (Int) -> Void

    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HighlightedText("Which apps should wait for Qur'an?", style: .h1)
            Text("Select the apps IqraLock should shield until you finish today's pages.")
                .iqraStyle(.body, color: IQColor.textSecondary)
            Button("Open app picker") { isPresented = true }
                .chunkyButton(.primary)
            Text("\(selection.applicationTokens.count) apps · \(selection.categoryTokens.count) categories")
                .iqraStyle(.caption, color: IQColor.textSecondary)
        }
        .familyActivityPicker(isPresented: $isPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            let count = newValue.applicationTokens.count + newValue.categoryTokens.count
            onSave(count)
        }
    }
}
#endif
