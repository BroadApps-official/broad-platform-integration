import SwiftUI

@MainActor
public struct BroadErrorView: View {
    private let content: BroadStateContent
    private let retry: BroadActionConfiguration?
    private let theme: BroadLoadableTheme

    public init(
        content: BroadStateContent,
        retry: BroadActionConfiguration?,
        theme: BroadLoadableTheme
    ) {
        self.content = content
        self.retry = retry
        self.theme = theme
    }

    public init(
        content: BroadStateContent,
        retry: BroadActionConfiguration? = nil
    ) {
        self.init(
            content: content,
            retry: retry,
            theme: .standard
        )
    }

    public var body: some View {
        BroadStateCardSurface(theme: theme) {
            VStack(spacing: theme.metrics.contentSpacing) {
                if let systemImageName = content.systemImageName {
                    BroadStateIcon(
                        systemImageName: systemImageName,
                        tint: theme.palette.failure,
                        theme: theme
                    )
                }

                BroadStateText(
                    content: content,
                    theme: theme,
                    alignment: .center
                )
                .multilineTextAlignment(.center)

                if let retry {
                    BroadActionButton(
                        configuration: retry,
                        tint: theme.palette.failure,
                        theme: theme
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
