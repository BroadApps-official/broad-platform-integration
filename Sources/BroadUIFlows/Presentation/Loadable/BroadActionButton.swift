import SwiftUI

@MainActor
public struct BroadActionButton: View {
    private let configuration: BroadActionConfiguration
    private let tint: Color
    private let theme: BroadLoadableTheme

    public init(
        configuration: BroadActionConfiguration,
        tint: Color,
        theme: BroadLoadableTheme
    ) {
        self.configuration = configuration
        self.tint = tint
        self.theme = theme
    }

    public init(
        configuration: BroadActionConfiguration,
        tint: Color
    ) {
        self.init(
            configuration: configuration,
            tint: tint,
            theme: .standard
        )
    }

    public var body: some View {
        Button(action: performAction) {
            HStack(spacing: theme.metrics.textSpacing) {
                if configuration.isInFlight {
                    ProgressView()
                        .tint(theme.palette.actionForeground)
                        .accessibilityHidden(true)
                }

                Text(currentTitle)
                    .font(theme.typography.action)
                    .foregroundStyle(theme.palette.actionForeground)
                    .multilineTextAlignment(.center)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: theme.metrics.minimumActionHeight
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!configuration.isEnabled || configuration.isInFlight)
        .accessibilityLabel(Text(configuration.accessibilityLabel ?? currentTitle))
    }

    private var currentTitle: String {
        if configuration.isInFlight, let inFlightTitle = configuration.inFlightTitle {
            return inFlightTitle
        }

        return configuration.title
    }

    private func performAction() {
        guard configuration.isEnabled, !configuration.isInFlight else {
            return
        }

        configuration.action()
    }
}
