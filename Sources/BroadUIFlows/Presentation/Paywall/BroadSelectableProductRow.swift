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
            HStack(alignment: .center, spacing: theme.metrics.spacing.productContent) {
                selectionIndicator

                description
                    .layoutPriority(1)

                priceBlock
                    .layoutPriority(2)
            }
            .padding(.horizontal, theme.metrics.spacing.productContent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: productRowHeight, alignment: .leading)
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
            Text(title)
                .font(theme.typography.productTitle)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionIndicator: some View {
        Circle()
            .fill(isSelected ? theme.palette.accent : Color.clear)
            .overlay {
                Circle()
                    .stroke(
                        isSelected
                            ? theme.palette.accent
                            : theme.palette.secondaryText,
                        lineWidth: isSelected ? 6 : theme.metrics.sizing.borderWidth
                    )
            }
            .overlay {
                if isSelected {
                    Circle()
                        .fill(theme.palette.actionForeground)
                        .frame(
                            width: BroadPaywallTheme.Sizing.selectionIndicatorDotDimension,
                            height: BroadPaywallTheme.Sizing.selectionIndicatorDotDimension
                        )
                }
            }
            .frame(
                width: BroadPaywallTheme.Sizing.selectionIndicatorDimension,
                height: BroadPaywallTheme.Sizing.selectionIndicatorDimension
            )
            .accessibilityHidden(true)
    }

    private var priceBlock: some View {
        VStack(alignment: .trailing, spacing: theme.metrics.spacing.text) {
            Text(price)
                .font(theme.typography.productPrice)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)

            if let period {
                Text(period)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
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

    private var productRowHeight: CGFloat {
        max(
            theme.metrics.sizing.minimumProductHeight,
            BroadPaywallTheme.Sizing.minimumInteractiveDimension
        )
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
