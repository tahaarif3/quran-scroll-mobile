import SwiftUI
import UIKit

public struct ChunkyButtonStyle: ButtonStyle {
    public enum Kind: Equatable, Sendable {
        case primary
        case secondary
        case dark
        case gold // lock CTA #F0C24B / shadow #C99A2C
        /// Nothing to sell. White fill, 2pt track border, no hard edge — used where the app
        /// deliberately declines to push: the goal is met, or the demo has not been played yet.
        case ghost
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
        let drop = IQShadow.chunkyOffset
        let shape = RoundedRectangle(cornerRadius: IQRadius.button, style: .continuous)

        // Stacking order is load-bearing. Chained `.background` modifiers layer back-to-front,
        // so the previous face-then-edge order painted the *edge* over the face: the darker
        // edge colour covered everything below y=6 (making the button read several steps darker
        // than #7A5A16) and left a 6pt strip of the lighter face showing along the top as a rim.
        //
        // The edge is a fixed slab 6pt below the face. Only the face and label travel down onto
        // it when pressed — moving the whole stack as well, as before, double-counted the offset.
        return ZStack {
            // A ghost has no hard edge — that shadow is what makes the primary look pressable,
            // and this variant is deliberately not asking to be pressed.
            shape.fill(edgeColor)
                .offset(y: drop)
                .opacity(kind == .ghost ? 0 : 1)
            shape.fill(faceColor)
                .offset(y: pressed ? drop : 0)
            if kind == .ghost {
                shape.strokeBorder(IQColor.track, lineWidth: 2)
            }
            configuration.label
                .font(IQFontStyle.button.font)
                .foregroundStyle(textColor)
                .offset(y: pressed ? drop : 0)
        }
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(height: IQSpace.buttonHeight)
        .animation(.easeOut(duration: 0.12), value: pressed)
        .allowsHitTesting(isEnabled)
    }

    private var faceColor: Color {
        guard isEnabled else { return IQColor.buttonDisabledFace }
        switch kind {
        case .primary: return IQColor.brandPrimary
        case .secondary: return Color.white
        case .dark: return IQColor.bgDark
        case .gold: return IQColor.lockCTA
        case .ghost: return Color.white
        }
    }

    private var edgeColor: Color {
        guard isEnabled else { return IQColor.buttonDisabledEdge }
        switch kind {
        case .primary: return IQColor.brandPrimaryShadow
        case .secondary: return IQColor.borderSubtle
        case .dark: return Color(hex: 0x2A2418)
        case .gold: return IQColor.lockCTAShadow
        case .ghost: return .clear
        }
    }

    private var textColor: Color {
        guard isEnabled else { return IQColor.buttonDisabledText }
        switch kind {
        case .primary, .dark: return IQColor.textInverse
        case .secondary: return IQColor.textInk
        case .gold: return IQColor.textOnGold
        case .ghost: return IQColor.brandPrimary
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
