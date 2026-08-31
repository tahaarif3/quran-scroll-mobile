import SwiftUI
import IqraLockKit

/// Full-screen confirmation when an ayah arrives too quickly to count on trust alone.
struct AyahReadConfirmationSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(IQColor.track)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            IQIconView(.book, size: 48)
                .padding(.bottom, 16)

            Text("Did you read that ayah?")
                .iqraStyle(.h2, color: IQColor.textInk)
                .multilineTextAlignment(.center)

            Text("That was quick, so it hasn't been counted yet. Only confirm if you actually read it.")
                .iqraStyle(.body, color: IQColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                ChunkyButton("Yes, count it") { onConfirm() }
                Button("Not yet") { onCancel() }
                    .iqraStyle(.bodyStrong, color: IQColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.top, 28)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, IQSpace.gutter)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(IQColor.bgSand)
    }
}
