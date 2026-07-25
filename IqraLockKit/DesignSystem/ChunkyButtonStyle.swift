import SwiftUI
import UIKit

public struct ChunkyButtonStyle: ButtonStyle {
    public enum Kind: Equatable, Sendable {
        case primary
        case secondary
        case dark
        case gold
    }

    public var kind: Kind
    public var isEnabled: Bool
    public var fullWidth: Bool

    public init(kind: Kind = .primary, isEnabled: Bool = true, fullWidth: Bool = true) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled

        return configuration.label
            .font(IQFontStyle.button.font)
            .tracking(IQFontStyle.button.tracking)
            .foregroundStyle(textColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .fill(edgeColor)
                    .offset(y: pressed ? 0 : IQShadow.chunkyOffset)
            )
            .background(
                RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous)
                    .fill(faceColor)
                    .offset(y: pressed ? IQShadow.chunkyOffset : 0)
            )
            .offset(y: pressed ? IQShadow.chunkyOffset : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .allowsHitTesting(isEnabled)
    }

    private var faceColor: Color {
        guard isEnabled else { return IQColor.buttonDisabledFace }
        switch kind {
        case .primary: return IQColor.olive
        case .secondary: return Color.white
        case .dark: return IQColor.bgDark
        case .gold: return IQColor.goldBright
        }
    }

    private var edgeColor: Color {
        guard isEnabled else { return IQColor.buttonDisabledEdge }
        switch kind {
        case .primary: return IQColor.oliveDeep
        case .secondary: return IQColor.borderSubtle
        case .dark: return Color(hex: 0x2A2418)
        case .gold: return Color(hex: 0xC49A2A)
        }
    }

    private var textColor: Color {
        guard isEnabled else { return IQColor.buttonDisabledText }
        switch kind {
        case .primary, .dark: return IQColor.textInverse
        case .secondary: return IQColor.textPrimary
        case .gold: return IQColor.textOnGold
        }
    }
}

public extension View {
    func chunkyButton(_ kind: ChunkyButtonStyle.Kind = .primary, enabled: Bool = true) -> some View {
        buttonStyle(ChunkyButtonStyle(kind: kind, isEnabled: enabled))
            .disabled(!enabled)
    }
}

public struct ChunkyButton: View {
    let title: String
    let kind: ChunkyButtonStyle.Kind
    let enabled: Bool
    let action: () -> Void

    public init(
        _ title: String,
        kind: ChunkyButtonStyle.Kind = .primary,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: {
            if enabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            }
        }) {
            Text(title)
        }
        .buttonStyle(ChunkyButtonStyle(kind: kind, isEnabled: enabled))
        .disabled(!enabled)
    }
}
