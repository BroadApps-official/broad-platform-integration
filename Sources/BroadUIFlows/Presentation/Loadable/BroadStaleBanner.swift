import SwiftUI

@MainActor
public struct BroadStaleBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            stateLayout {
                if let systemImageName = content.systemImageName {
                    BroadStateIcon(
                        systemImageName: systemImageName,
                        tint: theme.palette.warning,
                        theme: theme
                    )
                }

                BroadStateText(
                    content: content,
                    theme: theme,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if let retry {
                    BroadActionButton(
                        configuration: retry,
                        tint: theme.palette.warning,
                        theme: theme
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var stateLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: theme.metrics.contentSpacing
                )
            )
        } else {
            AnyLayout(
                HStackLayout(
                    alignment: .top,
                    spacing: theme.metrics.contentSpacing
                )
            )
        }
    }
}
