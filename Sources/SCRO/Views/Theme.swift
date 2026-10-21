import SwiftUI
import AppKit

/// shadcn-inspired styling: muted surfaces, hairline borders, one
/// high-contrast primary action, ghost buttons for secondary actions.
/// Colors are adaptive (label/windowBackground) so light & dark mode both work.
enum Theme {
    static let radius: CGFloat = 10
    static let radiusSmall: CGFloat = 8
    static let cardBackground = Color.primary.opacity(0.03)
    static let cardBorder = Color.primary.opacity(0.09)
    static let hoverBackground = Color.primary.opacity(0.06)
    static let primaryBackground = Color(nsColor: .labelColor)
    static let primaryForeground = Color(nsColor: .windowBackgroundColor)
}

// MARK: - Card container

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// MARK: - Button variants

/// shadcn `default` button — solid, high contrast.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.primaryForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                Theme.primaryBackground.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: Theme.radiusSmall)
            )
            .opacity(isEnabled ? 1 : 0.5)
    }
}

/// shadcn `outline` button — hairline border, muted fill.
struct OutlineButtonStyle: ButtonStyle {
    var isEnabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.65 : 1)
    }
}

/// shadcn `ghost` icon button — chromeless, hover reveals a muted fill.
struct GhostIconButton: View {
    let systemImage: String
    let help: String
    var danger = false
    var isEnabled = true
    let action: () -> Void

    // The @State macro needs Xcode's SwiftUIMacros plugin (CLT lacks it), so we
    // write the underlying State storage directly — identical runtime behavior.
    private var _hovered = State(initialValue: false)
    private var hovered: Bool { _hovered.wrappedValue }

    // Explicit init: the memberwise one would be private because of `_hovered`
    // (and older Swift toolchains disagree about that), breaking CI builds.
    init(
        systemImage: String,
        help: String,
        danger: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.help = help
        self.danger = danger
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(danger ? Color.red : Color.primary)
                .frame(width: 28, height: 26)
                .background(
                    hovered ? Theme.hoverBackground : .clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .onHover { _hovered.wrappedValue = $0 }
        .help(help)
    }
}
