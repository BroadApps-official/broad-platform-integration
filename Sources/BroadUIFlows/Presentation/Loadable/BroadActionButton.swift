import SwiftUI

@MainActor
struct BroadActionButton: View {
    let configuration: BroadActionConfiguration
    let tint: Color
    let theme: BroadLoadableTheme

    var body: some View {
        Button(action: performAction) {
            Text(currentTitle)
                .font(theme.typography.action)
                .foregroundStyle(theme.palette.actionForeground)
                .frame(minHeight: theme.metrics.minimumActionHeight)
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
