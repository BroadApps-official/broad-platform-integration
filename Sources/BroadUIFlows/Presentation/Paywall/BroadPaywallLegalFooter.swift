import SwiftUI

@MainActor
public struct BroadPaywallLegalFooter: View {
    private let links: [BroadPaywallLegalLink]
    private let theme: BroadPaywallTheme
    private let onOpen: @MainActor (BroadPaywallLegalLink) -> Void

    public init(
        links: [BroadPaywallLegalLink],
        theme: BroadPaywallTheme,
        onOpen: @escaping @MainActor (BroadPaywallLegalLink) -> Void
    ) {
        self.links = links
        self.theme = theme
        self.onOpen = onOpen
    }

    public var body: some View {
        if !links.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: theme.metrics.spacing.footer) {
                    legalButtons
                }

                VStack(alignment: .center, spacing: theme.metrics.spacing.footer) {
                    legalButtons
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var legalButtons: some View {
        ForEach(links) { link in
            Button {
                onOpen(link)
            } label: {
                Text(link.title)
                    .font(theme.typography.footer)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .underline()
                    .frame(
                        minWidth: BroadPaywallTheme.Sizing.minimumInteractiveDimension,
                        minHeight: BroadPaywallTheme.Sizing.minimumInteractiveDimension
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(BroadNoPressEffectButtonStyle())
            .accessibilityLabel(Text(link.accessibilityLabel ?? link.title))
        }
    }
}
