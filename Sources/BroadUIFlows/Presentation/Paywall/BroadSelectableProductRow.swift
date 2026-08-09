import BroadMonetization
import SwiftUI

@MainActor
public struct BroadSelectableProductRow: View {
    private let product: MonetizationProduct
    private let title: String
    private let subtitle: String?
    private let price: String
    private let period: String?
    private let isSelected: Bool
    private let selectedAccessibilityValue: String
    private let theme: BroadPaywallTheme
    private let action: @MainActor () -> Void

    public init(
        product: MonetizationProduct,
        content: BroadSelectableProductContent,
        isSelected: Bool,
        selectedAccessibilityValue: String,
        theme: BroadPaywallTheme,
        action: @escaping @MainActor () -> Void
    ) {
        self.product = product
        title = content.title
        subtitle = content.subtitle
        price = content.price
        period = content.period
        self.isSelected = isSelected
        self.selectedAccessibilityValue = selectedAccessibilityValue
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: theme.metrics.spacing.productContent) {
                    description
                    Spacer(minLength: theme.metrics.spacing.text)
                    priceBlock
                }

                VStack(alignment: .leading, spacing: theme.metrics.spacing.productContent) {
                    description
                    priceBlock
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(
                    theme.metrics.sizing.minimumProductHeight,
                    BroadPaywallTheme.Sizing.minimumInteractiveDimension
                ),
                alignment: .leading
            )
            .padding(theme.metrics.spacing.productContent)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(isSelected ? selectedAccessibilityValue : ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("broad-paywall-product-\(product.presentationID.rawValue)")
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
            HStack(alignment: .firstTextBaseline, spacing: theme.metrics.spacing.text) {
                Text(title)
                    .font(theme.typography.productTitle)
                    .foregroundStyle(theme.palette.primaryText)
                    .multilineTextAlignment(.leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.palette.accent)
                        .accessibilityHidden(true)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priceBlock: some View {
        VStack(alignment: .trailing, spacing: theme.metrics.spacing.text) {
            Text(price)
                .font(theme.typography.productPrice)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.trailing)

            if let period {
                Text(period)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var rowBackground: some View {
        RoundedRectangle(
            cornerRadius: theme.metrics.sizing.cornerRadius,
            style: .continuous
        )
        .fill(isSelected ? theme.palette.selectedSurface : theme.palette.surface)
        .overlay {
            RoundedRectangle(
                cornerRadius: theme.metrics.sizing.cornerRadius,
                style: .continuous
            )
            .stroke(
                isSelected ? theme.palette.selectedBorder : theme.palette.border,
                lineWidth: theme.metrics.sizing.borderWidth
            )
        }
    }

    private var accessibilityLabel: String {
        [title, subtitle, price, period]
            .compactMap { value in value }
            .joined(separator: ", ")
    }
}

public struct BroadSelectableProductContent: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let price: String
    public let period: String?

    public init(
        title: String,
        subtitle: String?,
        price: String,
        period: String?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.period = period
    }
}
