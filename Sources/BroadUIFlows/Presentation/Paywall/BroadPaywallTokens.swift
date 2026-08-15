import SwiftUI
import UIKit

@MainActor
public struct BroadPaywallTheme {
    public struct Palette {
        public let background: Color
        public let surface: Color
        public let primaryText: Color
        public let secondaryText: Color
        public let accent: Color
        public let actionForeground: Color
        public let border: Color
        public let selectedBorder: Color
        public let selectedSurface: Color

        public init(
            background: Color,
            surface: Color,
            primaryText: Color,
            secondaryText: Color,
            accent: Color,
            actionForeground: Color,
            border: Color,
            selectedBorder: Color,
            selectedSurface: Color
        ) {
            self.background = background
            self.surface = surface
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.accent = accent
            self.actionForeground = actionForeground
            self.border = border
            self.selectedBorder = selectedBorder
            self.selectedSurface = selectedSurface
        }
    }

    public struct Typography {
        public let title: Font
        public let subtitle: Font
        public let productTitle: Font
        public let productDetail: Font
        public let productPrice: Font
        public let action: Font
        public let footer: Font

        public init(
            title: Font,
            subtitle: Font,
            productTitle: Font,
            productDetail: Font,
            productPrice: Font,
            action: Font,
            footer: Font
        ) {
            self.title = title
            self.subtitle = subtitle
            self.productTitle = productTitle
            self.productDetail = productDetail
            self.productPrice = productPrice
            self.action = action
            self.footer = footer
        }
    }

    public struct Spacing {
        public let screen: CGFloat
        public let header: CGFloat
        public let content: CGFloat
        public let product: CGFloat
        public let productContent: CGFloat
        public let footer: CGFloat
        public let text: CGFloat

        public init(
            screen: CGFloat,
            header: CGFloat,
            content: CGFloat,
            product: CGFloat,
            productContent: CGFloat,
            footer: CGFloat,
            text: CGFloat
        ) {
            self.screen = screen
            self.header = header
            self.content = content
            self.product = product
            self.productContent = productContent
            self.footer = footer
            self.text = text
        }
    }

    public struct Sizing {
        public static let minimumInteractiveDimension: CGFloat =
            BroadInteractiveMetrics.minimumHitDimension
        static let selectionIndicatorDimension: CGFloat = 24
        static let selectionIndicatorDotDimension: CGFloat = 6

        public let cornerRadius: CGFloat
        public let minimumProductHeight: CGFloat
        public let minimumActionHeight: CGFloat
        public let closeButton: CGFloat
        public let borderWidth: CGFloat
        public let maximumContentWidth: CGFloat
        public let maximumRetryWidth: CGFloat

        public init(
            cornerRadius: CGFloat,
            minimumProductHeight: CGFloat,
            minimumActionHeight: CGFloat,
            closeButton: CGFloat,
            borderWidth: CGFloat,
            maximumContentWidth: CGFloat,
            maximumRetryWidth: CGFloat? = nil
        ) {
            self.cornerRadius = cornerRadius
            self.minimumProductHeight = max(
                minimumProductHeight,
                Self.minimumInteractiveDimension
            )
            self.minimumActionHeight = max(
                minimumActionHeight,
                Self.minimumInteractiveDimension
            )
            self.closeButton = max(
                closeButton,
                Self.minimumInteractiveDimension
            )
            self.borderWidth = borderWidth
            self.maximumContentWidth = maximumContentWidth
            self.maximumRetryWidth = maximumRetryWidth ?? maximumContentWidth
        }
    }

    public struct Metrics {
        public let spacing: Spacing
        public let sizing: Sizing

        public init(
            spacing: Spacing,
            sizing: Sizing
        ) {
            self.spacing = spacing
            self.sizing = sizing
        }
    }

    public let palette: Palette
    public let typography: Typography
    public let metrics: Metrics

    public init(
        palette: Palette,
        typography: Typography,
        metrics: Metrics
    ) {
        self.palette = palette
        self.typography = typography
        self.metrics = metrics
    }

    public static let standard = BroadPaywallTheme(
        palette: Palette(
            background: Color(uiColor: .systemBackground),
            surface: Color(uiColor: .secondarySystemBackground),
            primaryText: .primary,
            secondaryText: .secondary,
            accent: .accentColor,
            actionForeground: .white,
            border: Color(uiColor: .separator),
            selectedBorder: .accentColor,
            selectedSurface: .accentColor.opacity(0.1)
        ),
        typography: Typography(
            title: .largeTitle.bold(),
            subtitle: .body,
            productTitle: .headline,
            productDetail: .subheadline,
            productPrice: .headline,
            action: .headline,
            footer: .footnote
        ),
        metrics: Metrics(
            spacing: Spacing(
                screen: 20.0.scale,
                header: 12.0.scale,
                content: 20.0.scale,
                product: 12.0.scale,
                productContent: 14.0.scale,
                footer: 10.0.scale,
                text: 8.0.scale
            ),
            sizing: Sizing(
                cornerRadius: 20.0.scale,
                minimumProductHeight: 76.0.scale,
                minimumActionHeight: 50.0.scale,
                closeButton: 44.0.scale,
                borderWidth: 1.0.scale,
                maximumContentWidth: 680.0.scale,
                maximumRetryWidth: 320.0.scale
            )
        )
    )
}

@MainActor
private enum BroadPaywallLayoutScale {
    static var factor: CGFloat {
        let referenceWidth: CGFloat = 393
        let rawFactor = UIScreen.main.bounds.width / referenceWidth
        return min(max(rawFactor, 0.85), 1.25)
    }
}

private extension Double {
    @MainActor
    var scale: CGFloat {
        CGFloat(self) * BroadPaywallLayoutScale.factor
    }
}
