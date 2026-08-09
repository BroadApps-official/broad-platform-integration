import SwiftUI

@MainActor
struct BroadStateCardSurface<Content: View>: View {
    let theme: BroadLoadableTheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(theme.metrics.padding)
            .frame(maxWidth: .infinity)
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                    .stroke(theme.palette.border, lineWidth: theme.metrics.borderWidth)
            }
    }
}

@MainActor
struct BroadStateText: View {
    let content: BroadStateContent
    let theme: BroadLoadableTheme
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: theme.metrics.textSpacing) {
            Text(content.title)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)

            if let message = content.message {
                Text(message)
                    .font(theme.typography.message)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct BroadStateIcon: View {
    let systemImageName: String
    let tint: Color
    let theme: BroadLoadableTheme

    var body: some View {
        Image(systemName: systemImageName)
            .font(theme.typography.icon)
            .foregroundStyle(tint)
            .frame(width: theme.metrics.iconSize, height: theme.metrics.iconSize)
            .accessibilityHidden(true)
    }
}
