import SwiftUI
import UIKit

public struct OptionRow: View {
    public enum SelectionMode: Sendable {
        case single
        case multi
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let subtitle: String?
    let icon: IQIcon?
    let isSelected: Bool
    let mode: SelectionMode
    let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        icon: IQIcon? = nil,
        isSelected: Bool,
        mode: SelectionMode = .single,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isSelected = isSelected
        self.mode = mode
        self.action = action
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                if let icon {
                    IQIconView(icon)
                        .frame(width: IQIcon.rowColumnWidth)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .iqraStyle(.option, color: IQColor.textInk)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .iqraStyle(.caption, color: IQColor.textMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                trailingIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                    .fill(isSelected ? IQColor.oliveTint : IQColor.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                    .strokeBorder(
                        isSelected ? IQColor.accentOlive : IQColor.borderSubtle,
                        lineWidth: isSelected ? 2 : 1.6
                    )
            )
            // Fill and border cross-fade rather than snapping. The checkmark gets its own
            // spring below, so this stays a plain cross-fade.
            .animation(.easeOut(duration: 0.14), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        ZStack {
            Circle()
                .strokeBorder(IQColor.radioEmpty, lineWidth: 2)
                .frame(width: 24, height: 24)
                .opacity(isSelected ? 0 : 1)

            ZStack {
                Circle()
                    .fill(IQColor.accentOlive)
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .opacity(isSelected ? 1 : 0)
            // Scales 0.8 → 1 on a light spring. Both states stay mounted so the transition
            // animates; swapping them with `if` would just pop.
            .scaleEffect(isSelected ? 1 : 0.8)
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(response: 0.3, dampingFraction: 0.6),
            value: isSelected
        )
    }

    private var accessibilityLabelText: String {
        var parts = [title]
        if let subtitle { parts.append(subtitle) }
        parts.append(isSelected ? "selected" : "not selected")
        return parts.joined(separator: ", ")
    }
}
