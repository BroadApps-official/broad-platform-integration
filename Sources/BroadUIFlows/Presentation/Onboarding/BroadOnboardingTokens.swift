import SwiftUI
import UIKit

@MainActor
public struct BroadOnboardingTheme {
    public struct Palette {
        public let background: Color
        public let surface: Color
        public let primaryText: Color
        public let secondaryText: Color
        public let accent: Color
        public let actionForeground: Color
        public let progressInactive: Color
        public let border: Color

        public init(
            background: Color,
            surface: Color,
            primaryText: Color,
            secondaryText: Color,
            accent: Color,
            actionForeground: Color,
            progressInactive: Color,
            border: Color
        ) {
            self.background = background
            self.surface = surface
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.accent = accent
            self.actionForeground = actionForeground
            self.progressInactive = progressInactive
            self.border = border
        }
    }

    public struct Typography {
        public let title: Font
        public let subtitle: Font
        public let action: Font
        public let footer: Font

        public init(
            title: Font,
            subtitle: Font,
            action: Font,
            footer: Font
        ) {
            self.title = title
            self.subtitle = subtitle
            self.action = action
            self.footer = footer
        }
    }

    public struct Metrics {
        public static let minimumInteractiveDimension: CGFloat =
            BroadInteractiveMetrics.minimumHitDimension

        public let pageSpacing: CGFloat
        public let textSpacing: CGFloat
        public let controlSpacing: CGFloat
        public let screenPadding: CGFloat
        public let surfacePadding: CGFloat
        public let cornerRadius: CGFloat
        public let progressSpacing: CGFloat
        public let progressHeight: CGFloat
        public let borderWidth: CGFloat
        public let minimumActionHeight: CGFloat

        public init(
            pageSpacing: CGFloat,
            textSpacing: CGFloat,
            controlSpacing: CGFloat,
            screenPadding: CGFloat,
            surfacePadding: CGFloat,
            cornerRadius: CGFloat,
            progressSpacing: CGFloat,
            progressHeight: CGFloat,
            borderWidth: CGFloat,
            minimumActionHeight: CGFloat
        ) {
            self.pageSpacing = pageSpacing
            self.textSpacing = textSpacing
            self.controlSpacing = controlSpacing
            self.screenPadding = screenPadding
            self.surfacePadding = surfacePadding
            self.cornerRadius = cornerRadius
            self.progressSpacing = progressSpacing
            self.progressHeight = progressHeight
            self.borderWidth = borderWidth
            self.minimumActionHeight = max(
                minimumActionHeight,
                Self.minimumInteractiveDimension
            )
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

    public static let standard = BroadOnboardingTheme(
        palette: Palette(
            background: Color(uiColor: .systemBackground),
            surface: Color(uiColor: .secondarySystemBackground),
            primaryText: .primary,
            secondaryText: .secondary,
            accent: .accentColor,
            actionForeground: .white,
            progressInactive: .secondary.opacity(0.24),
            border: .secondary.opacity(0.18)
        ),
        typography: Typography(
            title: .largeTitle.bold(),
            subtitle: .body,
            action: .headline,
            footer: .footnote
        ),
        metrics: Metrics(
            pageSpacing: 24.0.scale,
            textSpacing: 10.0.scale,
            controlSpacing: 16.0.scale,
            screenPadding: 20.0.scale,
            surfacePadding: 18.0.scale,
            cornerRadius: 24.0.scale,
            progressSpacing: 5.0.scale,
            progressHeight: 4.0.scale,
            borderWidth: 1.0.scale,
            minimumActionHeight: 50.0.scale
        )
    )
}

@MainActor
private enum BroadOnboardingLayoutScale {
    static var factor: CGFloat {
        let referenceWidth: CGFloat = 393
        let rawFactor = UIScreen.main.bounds.width / referenceWidth
        return min(max(rawFactor, 0.85), 1.25)
    }
}

private extension Double {
    @MainActor
    var scale: CGFloat {
        CGFloat(self) * BroadOnboardingLayoutScale.factor
    }
}
