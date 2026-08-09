import SwiftUI

@MainActor
public struct BroadLoaderView<Media: View>: View {
    private let content: BroadStateContent
    private let theme: BroadLoadableTheme
    private let media: Media

    public init(
        content: BroadStateContent,
        theme: BroadLoadableTheme,
        @ViewBuilder media: () -> Media
    ) {
        self.content = content
        self.theme = theme
        self.media = media()
    }

    public init(
        content: BroadStateContent,
        @ViewBuilder media: () -> Media
    ) {
        self.init(
            content: content,
            theme: .standard,
            media: media
        )
    }

    public var body: some View {
        BroadStateCardSurface(theme: theme) {
            VStack(spacing: theme.metrics.contentSpacing) {
                media
                    .accessibilityHidden(true)

                ProgressView()
                    .controlSize(.large)
                    .tint(theme.palette.accent)
                    .frame(width: theme.metrics.iconSize, height: theme.metrics.iconSize)
                    .accessibilityLabel(Text(accessibilityText))

                BroadStateText(
                    content: content,
                    theme: theme,
                    alignment: .center
                )
                .multilineTextAlignment(.center)
                .accessibilityHidden(true)
            }
        }
    }

    private var accessibilityText: String {
        guard let message = content.message else {
            return content.title
        }

        return "\(content.title). \(message)"
    }
}

public extension BroadLoaderView where Media == EmptyView {
    init(
        content: BroadStateContent,
        theme: BroadLoadableTheme
    ) {
        self.init(content: content, theme: theme) {
            EmptyView()
        }
    }

    init(content: BroadStateContent) {
        self.init(content: content, theme: .standard)
    }
}
