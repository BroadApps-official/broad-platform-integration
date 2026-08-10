import BroadMonetization
import SwiftUI

@MainActor
struct BroadPaymentMethodRow: View {
    let method: CheckoutMethod
    let isSelected: Bool
    let title: String
    let theme: BroadPaywallTheme
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.metrics.spacing.productContent) {
                Image(systemName: systemImageName)
                    .font(theme.typography.productTitle)
                    .foregroundStyle(theme.palette.accent)
                    .frame(width: theme.metrics.sizing.closeButton)
                    .accessibilityHidden(true)

                Text(title)
                    .font(theme.typography.productTitle)
                    .foregroundStyle(theme.palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    isSelected
                        ? theme.palette.accent
                        : theme.palette.secondaryText
                )
            }
            .frame(
                maxWidth: .infinity,
                minHeight: theme.metrics.sizing.minimumProductHeight
            )
            .padding(.horizontal, theme.metrics.spacing.productContent)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
    }

    private var background: some View {
        RoundedRectangle(
            cornerRadius: theme.metrics.sizing.cornerRadius,
            style: .continuous
        )
        .fill(
            isSelected
                ? theme.palette.selectedSurface
                : theme.palette.surface
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: theme.metrics.sizing.cornerRadius,
                style: .continuous
            )
            .stroke(
                isSelected
                    ? theme.palette.selectedBorder
                    : theme.palette.border,
                lineWidth: theme.metrics.sizing.borderWidth
            )
        }
    }

    private var systemImageName: String {
        switch method {
        case .apple:
            "apple.logo"
        case .sbp:
            "qrcode"
        case .card:
            "creditcard"
        }
    }
}
