import SwiftUI

@MainActor
public struct BroadPaywallPrimaryButton: View {
    private let title: String
    private let isEnabled: Bool
    private let isInFlight: Bool
    private let theme: BroadPaywallTheme
    private let action: @MainActor () -> Void

    public init(
        title: String,
        isEnabled: Bool,
        isInFlight: Bool,
        theme: BroadPaywallTheme,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isInFlight = isInFlight
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: performAction) {
            HStack(spacing: theme.metrics.spacing.text) {
                if isInFlight {
                    ProgressView()
                        .tint(theme.palette.actionForeground)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(theme.typography.action)
                    .foregroundStyle(theme.palette.actionForeground)
                    .multilineTextAlignment(.center)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(
                    theme.metrics.sizing.minimumActionHeight,
                    BroadPaywallTheme.Sizing.minimumInteractiveDimension
                )
            )
            .padding(.horizontal, theme.metrics.spacing.productContent)
            .background(
                RoundedRectangle(
                    cornerRadius: theme.metrics.sizing.cornerRadius,
                    style: .continuous
                )
                .fill(theme.palette.accent)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
        .allowsHitTesting(isEnabled && !isInFlight)
        .disabled(!isEnabled || isInFlight)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }

    private func performAction() {
        guard isEnabled, !isInFlight else {
            return
        }

        action()
    }
}
