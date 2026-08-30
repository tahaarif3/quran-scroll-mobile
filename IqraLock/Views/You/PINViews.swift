import SwiftUI
import IqraLockKit

struct PINEntryView: View {
    let title: String
    let subtitle: String
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var error = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(subtitle)
                    .iqraStyle(.body, color: IQColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.custom("Nunito-Bold", size: 28))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: IQRadius.card, style: .continuous)
                            .strokeBorder(error ? Color.red : IQColor.track, lineWidth: 2)
                    )
                    .padding(.horizontal, IQSpace.gutter)
                    .focused($focused)

                if error {
                    Text("Incorrect PIN. Try again.")
                        .iqraStyle(.caption, color: .red)
                }

                ChunkyButton("Unlock") { verify() }
                    .padding(.horizontal, IQSpace.gutter)
                    .disabled(pin.count < 4)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func verify() {
        if PINStore.verify(pin: pin) {
            onSuccess()
        } else {
            error = true
            pin = ""
        }
    }
}

struct ParentPINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirm = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New PIN (4+ digits)", text: $pin)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirm)
                        .keyboardType(.numberPad)
                } footer: {
                    Text("Child mode locks settings, bathroom breaks, and turning off blocking behind this PIN.")
                }

                if PINStore.isConfigured {
                    Section {
                        Button("Remove PIN", role: .destructive) {
                            PINStore.delete()
                            dismiss()
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Parent PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(pin.count < 4 || pin != confirm)
                }
            }
        }
    }

    private func save() {
        guard pin == confirm else {
            message = "PINs don't match."
            return
        }
        guard PINStore.save(pin: pin) else {
            message = "Could not save PIN."
            return
        }
        dismiss()
    }
}
