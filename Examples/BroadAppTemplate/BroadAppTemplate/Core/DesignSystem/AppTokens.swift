import BroadUIFlows
import SwiftUI

@MainActor
enum AppTokens {
    enum Color {
        static let background = SwiftUI.Color(red: 0.035, green: 0.055, blue: 0.11)
        static let surface = SwiftUI.Color.white.opacity(0.06)
        static let primaryText = SwiftUI.Color.white
        static let secondaryText = SwiftUI.Color.white.opacity(0.68)
        static let border = SwiftUI.Color.white.opacity(0.12)
        static let accent = SwiftUI.Color(red: 0.49, green: 0.46, blue: 1.0)
        static let core = SwiftUI.Color(red: 0.23, green: 0.51, blue: 0.96)
        static let monetization = SwiftUI.Color(red: 0.06, green: 0.73, blue: 0.51)
        static let uiFlows = SwiftUI.Color(red: 0.93, green: 0.28, blue: 0.60)
        static let success = SwiftUI.Color(red: 0.18, green: 0.78, blue: 0.54)
        static let warning = SwiftUI.Color(red: 1.0, green: 0.68, blue: 0.2)
        static let failure = SwiftUI.Color(red: 1.0, green: 0.34, blue: 0.42)
    }

    enum Font {
        static let eyebrow = SwiftUI.Font.caption.weight(.bold)
        static let heroTitle = SwiftUI.Font.largeTitle.weight(.bold)
        static let body = SwiftUI.Font.body
        static let cardTitle = SwiftUI.Font.headline
        static let caption = SwiftUI.Font.subheadline
        static let badge = SwiftUI.Font.caption.weight(.semibold)
        static let moduleIcon = SwiftUI.Font.title3.weight(.semibold)
        static let statusIcon = SwiftUI.Font.title2.weight(.semibold)
        static let onboardingIcon = SwiftUI.Font.largeTitle.weight(.bold)
        static let mainIcon = SwiftUI.Font.title.weight(.bold)
        static let fixtureStatusIcon = SwiftUI.Font.system(size: 54, weight: .semibold)
        static let fixtureCode = SwiftUI.Font.system(
            .footnote,
            design: .monospaced
        ).weight(.semibold)
    }

    @MainActor
    enum Spacing {
        static let tiny = 6.0.scale
        static let small = 10.0.scale
        static let cardGap = 12.0.scale
        static let cardContent = 14.0.scale
        static let cardPadding = 18.0.scale
        static let section = 28.0.scale
        static let hero = 34.0.scale
        static let screenHorizontal = 20.0.scale
        static let screenVertical = 28.0.scale
    }

    @MainActor
    enum Radius {
        static let icon = 13.0.scale
        static let card = 22.0.scale
        static let hero = 30.0.scale
    }

    @MainActor
    enum Size {
        static let moduleIcon = 46.0.scale
        static let statusIcon = 28.0.scale
        static let onboardingMedia = 230.0.scale
        static let onboardingIcon = 88.0.scale
    }

    @MainActor
    enum Border {
        static let thin = 1.0.scale
    }

    enum Opacity {
        static let iconBackground = 0.16
        static let border = 0.5
    }

    enum Scale {
        static let minimumTitle = 0.8
    }

    static let paywallTheme = BroadPaywallTheme(
        palette: BroadPaywallTheme.Palette(
            background: Color.background,
            surface: Color.surface,
            primaryText: Color.primaryText,
            secondaryText: Color.secondaryText,
            accent: Color.accent,
            actionForeground: .white,
            border: Color.border,
            selectedBorder: Color.accent,
            selectedSurface: Color.accent.opacity(0.2)
        ),
        typography: BroadPaywallTheme.Typography(
            title: .largeTitle.bold(),
            subtitle: .body,
            productTitle: .headline,
            productDetail: .subheadline,
            productPrice: .headline,
            action: .headline,
            footer: .footnote
        ),
        metrics: BroadPaywallTheme.Metrics(
            spacing: BroadPaywallTheme.Spacing(
                screen: 16.0.scale,
                header: 12.0.scale,
                content: 16.0.scale,
                product: 8.0.scale,
                productContent: 14.0.scale,
                footer: 8.0.scale,
                text: 6.0.scale
            ),
            sizing: BroadPaywallTheme.Sizing(
                cornerRadius: 20.0.scale,
                minimumProductHeight: 88.0.scale,
                minimumActionHeight: 54.0.scale,
                closeButton: 44.0.scale,
                borderWidth: 1.0.scale,
                maximumContentWidth: 680.0.scale,
                maximumRetryWidth: 320.0.scale
            )
        )
    )
}
