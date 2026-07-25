import SwiftUI
import UIKit

public struct OptionRow: View {
    public enum SelectionMode: Sendable {
        case single
        case multi
    }

    let title: String
    let subtitle: String?
    let emoji: String?
    let isSelected: Bool
    let mode: SelectionMode
    let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        emoji: String? = nil,
        isSelected: Bool,
        mode: SelectionMode = .single,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emoji = emoji
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
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 28)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .iqraStyle(.bodyStrong, color: IQColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .iqraStyle(.caption, color: IQColor.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                trailingIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .fill(isSelected ? IQColor.oliveTint : IQColor.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? IQColor.borderOlive : IQColor.borderSubtle,
                        lineWidth: isSelected ? 2 : 1.6
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        switch mode {
        case .single:
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? IQColor.olive : IQColor.ringEmpty, lineWidth: 2)
                    .frame(width: 24, height: 24)
                if isSelected {
                    Circle()
                        .fill(IQColor.olive)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        case .multi:
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(IQColor.olive)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(IQColor.ringEmpty, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }

    private var accessibilityLabelText: String {
        var parts = [title]
        if let subtitle { parts.append(subtitle) }
        parts.append(isSelected ? "selected" : "not selected")
        return parts.joined(separator: ", ")
    }
}
