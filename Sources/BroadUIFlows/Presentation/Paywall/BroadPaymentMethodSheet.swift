import BroadMonetization
import SwiftUI

@MainActor
public struct BroadPaymentMethodSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let methods: [CheckoutMethod]
    private let copy: BroadPaywallCopy
    private let theme: BroadPaywallTheme
    private let onSelect: @MainActor (CheckoutMethod) -> Void
    private let onCancel: @MainActor () -> Void

    public init(
        methods: [CheckoutMethod],
        copy: BroadPaywallCopy,
        theme: BroadPaywallTheme,
        onSelect: @escaping @MainActor (CheckoutMethod) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        precondition(
            Set(methods.map(\.rawValue)).count == methods.count,
            "Payment method sheet does not accept duplicates"
        )

        self.methods = methods
        self.copy = copy
        self.theme = theme
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.content) {
                Text(copy.checkout.title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.palette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: theme.metrics.spacing.product) {
                    ForEach(methods, id: \.rawValue) { method in
                        paymentMethodButton(method)
                    }
                }

                Button(copy.actions.cancelTitle) {
                    onCancel()
                    dismiss()
                }
                .font(theme.typography.action)
                .foregroundStyle(theme.palette.secondaryText)
                .frame(
                    maxWidth: .infinity,
                    minHeight: max(
                        theme.metrics.sizing.minimumActionHeight,
                        BroadPaywallTheme.Sizing.minimumInteractiveDimension
                    )
                )
                .buttonStyle(BroadNoPressEffectButtonStyle())
            }
            .padding(theme.metrics.spacing.screen)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.palette.background.ignoresSafeArea())
    }

    private func paymentMethodButton(_ method: CheckoutMethod) -> some View {
        Button {
            onSelect(method)
            dismiss()
        } label: {
            HStack(spacing: theme.metrics.spacing.productContent) {
                Image(systemName: systemImageName(for: method))
                    .font(theme.typography.productTitle)
                    .foregroundStyle(theme.palette.accent)
                    .frame(width: theme.metrics.sizing.closeButton)
                    .accessibilityHidden(true)

                Text(copy.checkout.title(for: method))
                    .font(theme.typography.productTitle)
                    .foregroundStyle(theme.palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(
                    theme.metrics.sizing.minimumProductHeight,
                    BroadPaywallTheme.Sizing.minimumInteractiveDimension
                )
            )
            .padding(.horizontal, theme.metrics.spacing.productContent)
            .background(
                RoundedRectangle(
                    cornerRadius: theme.metrics.sizing.cornerRadius,
                    style: .continuous
                )
                .fill(theme.palette.surface)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: theme.metrics.sizing.cornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        theme.palette.border,
                        lineWidth: theme.metrics.sizing.borderWidth
                    )
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
    }

    private func systemImageName(for method: CheckoutMethod) -> String {
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
