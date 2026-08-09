import SwiftUI

extension BroadPaywallView {
    var stickyFooter: some View {
        VStack(spacing: theme.metrics.spacing.footer) {
            if case .content = viewModel.state {
                BroadPaywallPrimaryButton(
                    title: viewModel.configuration.copy.actions.purchaseTitle,
                    isEnabled: viewModel.canPurchase,
                    isInFlight: viewModel.isResolvingCheckoutMethods || viewModel.isPurchaseInFlight,
                    theme: theme,
                    action: viewModel.purchaseButtonTapped
                )
            }

            inlineFeedback
            restoreButton

            BroadPaywallLegalFooter(
                links: viewModel.configuration.legalLinks,
                theme: theme
            ) { link in
                safariDestination = BroadPaywallSafariDestination(url: link.url)
            }
        }
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.top, theme.metrics.spacing.footer)
        .padding(.bottom, theme.metrics.spacing.screen)
        .background(theme.palette.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.metrics.sizing.borderWidth)
        }
    }

    @ViewBuilder
    var inlineFeedback: some View {
        if let feedback = viewModel.inlineFeedback {
            switch feedback {
            case let .notice(message):
                feedbackText(message, isFailure: false)
            case let .failure(error):
                feedbackText(error.userMessage, isFailure: true)
            }
        }
    }

    var restoreButton: some View {
        Button(action: viewModel.restorePurchases) {
            HStack(spacing: theme.metrics.spacing.text) {
                if viewModel.isRestoreInFlight {
                    ProgressView()
                        .tint(theme.palette.secondaryText)
                        .accessibilityHidden(true)
                }

                Text(restoreTitle)
                    .font(theme.typography.action)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(
                    theme.metrics.sizing.minimumActionHeight,
                    BroadPaywallTheme.Sizing.minimumInteractiveDimension
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
        .allowsHitTesting(
            !viewModel.isBusy && !viewModel.isFinancialOperationPending
        )
        .disabled(viewModel.isBusy || viewModel.isFinancialOperationPending)
        .accessibilityLabel(Text(restoreTitle))
    }

    var retryButton: some View {
        BroadPaywallPrimaryButton(
            title: viewModel.configuration.copy.actions.retryTitle,
            isEnabled: !viewModel.isBusy,
            isInFlight: false,
            theme: theme,
            action: viewModel.retry
        )
        .frame(maxWidth: theme.metrics.sizing.maximumRetryWidth)
    }

    var restoreTitle: String {
        viewModel.isRestoreInFlight
            ? viewModel.configuration.copy.actions.restoringTitle
            : viewModel.configuration.copy.actions.restoreTitle
    }

    func feedbackText(
        _ message: String,
        isFailure: Bool
    ) -> some View {
        Text(message)
            .font(theme.typography.footer)
            .foregroundStyle(isFailure ? theme.palette.primaryText : theme.palette.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
