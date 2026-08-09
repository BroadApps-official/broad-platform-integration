import SwiftUI
import UIKit

@MainActor
public struct BroadLoadableTheme {
    public struct Palette {
        public let surface: Color
        public let primaryText: Color
        public let secondaryText: Color
        public let accent: Color
        public let warning: Color
        public let failure: Color
        public let border: Color
        public let actionForeground: Color

        public init(
            surface: Color,
            primaryText: Color,
            secondaryText: Color,
            accent: Color,
            warning: Color,
            failure: Color,
            border: Color,
            actionForeground: Color
        ) {
            self.surface = surface
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.accent = accent
            self.warning = warning
            self.failure = failure
            self.border = border
            self.actionForeground = actionForeground
        }
    }

    public struct Typography {
        public let title: Font
        public let message: Font
        public let action: Font
        public let icon: Font

        public init(
            title: Font,
            message: Font,
            action: Font,
            icon: Font
        ) {
            self.title = title
            self.message = message
            self.action = action
            self.icon = icon
        }
    }

    public struct Metrics {
        public let contentSpacing: CGFloat
        public let textSpacing: CGFloat
        public let padding: CGFloat
        public let cornerRadius: CGFloat
        public let iconSize: CGFloat
        public let borderWidth: CGFloat
        public let minimumActionHeight: CGFloat
        public let compactPadding: CGFloat

        public init(
            contentSpacing: CGFloat,
            textSpacing: CGFloat,
            padding: CGFloat,
            cornerRadius: CGFloat,
            iconSize: CGFloat,
            borderWidth: CGFloat,
            minimumActionHeight: CGFloat,
            compactPadding: CGFloat
        ) {
            self.contentSpacing = contentSpacing
            self.textSpacing = textSpacing
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.iconSize = iconSize
            self.borderWidth = borderWidth
            self.minimumActionHeight = minimumActionHeight
            self.compactPadding = compactPadding
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

    public static let standard = BroadLoadableTheme(
        palette: Palette(
            surface: Color(uiColor: .secondarySystemBackground),
            primaryText: .primary,
            secondaryText: .secondary,
            accent: .accentColor,
            warning: .orange,
            failure: .red,
            border: .secondary.opacity(0.24),
            actionForeground: .white
        ),
        typography: Typography(
            title: .headline,
            message: .subheadline,
            action: .callout.weight(.semibold),
            icon: .title2.weight(.semibold)
        ),
        metrics: Metrics(
            contentSpacing: 14.0.scale,
            textSpacing: 6.0.scale,
            padding: 18.0.scale,
            cornerRadius: 22.0.scale,
            iconSize: 28.0.scale,
            borderWidth: 1.0.scale,
            minimumActionHeight: 44.0.scale,
            compactPadding: 8.0.scale
        )
    )
}

@MainActor
private enum BroadLoadableLayoutScale {
    static var factor: CGFloat {
        let referenceWidth: CGFloat = 393
        let rawFactor = UIScreen.main.bounds.width / referenceWidth
        return min(max(rawFactor, 0.85), 1.25)
    }
}

private extension Double {
    @MainActor
    var scale: CGFloat {
        CGFloat(self) * BroadLoadableLayoutScale.factor
    }
}
