import SwiftUI

@MainActor
public struct BroadEmptyView: View {
    private let content: BroadStateContent
    private let action: BroadActionConfiguration?
    private let theme: BroadLoadableTheme

    public init(
        content: BroadStateContent,
        action: BroadActionConfiguration?,
        theme: BroadLoadableTheme
    ) {
        self.content = content
        self.action = action
        self.theme = theme
    }

    public init(
        content: BroadStateContent,
        action: BroadActionConfiguration? = nil
    ) {
        self.init(
            content: content,
            action: action,
            theme: .standard
        )
    }

    public var body: some View {
        BroadStateCardSurface(theme: theme) {
            VStack(spacing: theme.metrics.contentSpacing) {
                if let systemImageName = content.systemImageName {
                    BroadStateIcon(
                        systemImageName: systemImageName,
                        tint: theme.palette.accent,
                        theme: theme
                    )
                }

                BroadStateText(
                    content: content,
                    theme: theme,
                    alignment: .center
                )
                .multilineTextAlignment(.center)

                if let action {
                    BroadActionButton(
                        configuration: action,
                        tint: theme.palette.accent,
                        theme: theme
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
