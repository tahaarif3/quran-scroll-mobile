import SwiftUI
import IqraLockKit

/// In-reader controls for text size and reading style — changes apply immediately.
struct ReaderSettingsSheet: View {
    @Binding var textSize: CGFloat
    @Binding var readingStyle: ReadingStyleAnswer
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Arabic text size") {
                    HStack {
                        Text("Aa")
                            .font(.custom("Amiri-Bold", size: 20))
                        Slider(value: $textSize, in: 20...40, step: 1)
                            .tint(IQColor.accentOlive)
                        Text("Aa")
                            .font(.custom("Amiri-Bold", size: 32))
                    }
                    Text("\(Int(textSize))pt")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                }

                Section("Reading style") {
                    Picker("Style", selection: $readingStyle) {
                        ForEach(ReadingStyleAnswer.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    LabeledContent("Translation", value: "Saheeh International")
                } footer: {
                    Text("More translations coming soon.")
                }
            }
            .navigationTitle("Reader settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
