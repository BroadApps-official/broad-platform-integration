import SwiftUI

@MainActor
public struct BroadRefreshIndicator: View {
    private let accessibilityLabel: String
    private let theme: BroadLoadableTheme

    public init(
        accessibilityLabel: String,
        theme: BroadLoadableTheme
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.theme = theme
    }

    public init(accessibilityLabel: String) {
        self.init(
            accessibilityLabel: accessibilityLabel,
            theme: .standard
        )
    }

    public var body: some View {
        ProgressView()
            .tint(theme.palette.accent)
            .frame(width: theme.metrics.iconSize, height: theme.metrics.iconSize)
            .padding(theme.metrics.compactPadding)
            .background(theme.palette.surface)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(theme.palette.border, lineWidth: theme.metrics.borderWidth)
            }
            .accessibilityLabel(Text(accessibilityLabel))
            .allowsHitTesting(false)
    }
}
