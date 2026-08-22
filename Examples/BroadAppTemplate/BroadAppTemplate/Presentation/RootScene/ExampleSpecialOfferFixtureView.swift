import BroadUIFlows
import SwiftUI

@MainActor
struct ExampleSpecialOfferFixtureView: View {
    @ObservedObject var viewModel: ExampleSpecialOfferFixtureViewModel

    var body: some View {
        Group {
            if let paywallViewModel = viewModel.paywallViewModel {
                BroadPaywallView(
                    viewModel: paywallViewModel,
                    theme: AppTokens.paywallTheme,
                    productFormatter: BroadPaywallProductFormatter(),
                    onClose: {},
                    onCompleted: { _ in }
                )
            } else {
                statusView
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var statusView: some View {
        ZStack {
            AppTokens.Color.background.ignoresSafeArea()

            VStack(spacing: AppTokens.Spacing.cardPadding) {
                Image(systemName: viewModel.isLoading ? "clock.arrow.circlepath" : "checkmark.shield")
                    .font(AppTokens.Font.fixtureStatusIcon)
                    .foregroundStyle(
                        viewModel.isLoading
                            ? AppTokens.Color.accent
                            : AppTokens.Color.success
                    )

                Text(viewModel.statusTitle)
                    .font(AppTokens.Font.heroTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)
                    .multilineTextAlignment(.center)

                Text(viewModel.statusMessage)
                    .font(AppTokens.Font.body)
                    .foregroundStyle(AppTokens.Color.secondaryText)
                    .multilineTextAlignment(.center)

                Text("Fixture: -\(viewModel.scenario.rawValue)")
                    .font(AppTokens.Font.fixtureCode)
                    .foregroundStyle(AppTokens.Color.accent)
                    .padding(.horizontal, AppTokens.Spacing.cardContent)
                    .padding(.vertical, AppTokens.Spacing.small)
                    .background(AppTokens.Color.surface)
                    .clipShape(Capsule())
            }
            .padding(AppTokens.Spacing.screenHorizontal)
        }
    }
}
