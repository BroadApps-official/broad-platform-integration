import BroadUIFlows
import SwiftUI

/// Demonstrates the logic-only integration: all layout belongs to the app,
/// while page progression, completion and ATT stay inside the platform host.
struct ExampleCustomOnboardingView: View {
    let viewModel: OnboardingViewModel
    let onFooterAction: @MainActor (OnboardingFooterDestination) -> Void
    let onCompleted: @MainActor () -> Void

    var body: some View {
        BroadOnboardingFlowHost(
            viewModel: viewModel,
            onCompleted: onCompleted
        ) { viewModel, actions in
            ScrollView {
                VStack(spacing: AppTokens.Spacing.section) {
                    header(viewModel: viewModel)

                    if let page = viewModel.currentPage {
                        ExampleOnboardingMediaView(descriptor: page.media)

                        VStack(spacing: AppTokens.Spacing.small) {
                            Text(page.title)
                                .font(AppTokens.Font.heroTitle)
                                .foregroundStyle(AppTokens.Color.primaryText)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let subtitle = page.subtitle {
                                Text(subtitle)
                                    .font(AppTokens.Font.body)
                                    .foregroundStyle(AppTokens.Color.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Button(action: actions.advance) {
                        Text(actionTitle(viewModel: viewModel))
                            .font(AppTokens.Font.cardTitle)
                            .foregroundStyle(AppTokens.Color.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(AppTokens.Spacing.cardContent)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTokens.Color.accent)

                    footer(viewModel: viewModel)
                }
                .padding(.horizontal, AppTokens.Spacing.screenHorizontal)
                .padding(.vertical, AppTokens.Spacing.screenVertical)
            }
            .background(AppTokens.Color.background.ignoresSafeArea())
        }
    }

    private func header(viewModel: OnboardingViewModel) -> some View {
        HStack {
            Text("Свой интерфейс")
                .font(AppTokens.Font.eyebrow)
                .foregroundStyle(AppTokens.Color.accent)

            Spacer()

            Text("\(viewModel.currentIndex + 1) / \(viewModel.configuration.pages.count)")
                .font(AppTokens.Font.badge)
                .foregroundStyle(AppTokens.Color.secondaryText)
        }
    }

    private func footer(viewModel: OnboardingViewModel) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                footerButtons(viewModel: viewModel)
            }

            VStack(spacing: AppTokens.Spacing.tiny) {
                footerButtons(viewModel: viewModel)
            }
        }
    }

    private func footerButtons(viewModel: OnboardingViewModel) -> some View {
        ForEach(viewModel.configuration.footerLinks) { link in
            Button(link.title) {
                onFooterAction(link.destination)
            }
            .font(AppTokens.Font.caption)
            .foregroundStyle(AppTokens.Color.secondaryText)
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
        }
    }

    private func actionTitle(viewModel: OnboardingViewModel) -> String {
        viewModel.isLastPage
            ? viewModel.configuration.completionTitle
            : viewModel.configuration.continueTitle
    }
}
