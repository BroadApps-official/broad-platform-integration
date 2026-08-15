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
            compactFooterActions
        }
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.top, theme.metrics.spacing.footer)
        .padding(.bottom, theme.metrics.spacing.screen)
        .background(theme.palette.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.metrics.sizing.borderWidth)
                .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
        }
    }

    @ViewBuilder
    var compactFooterActions: some View {
        let links = viewModel.configuration.legalLinks

        if links.count == 2 {
            HStack(spacing: 0) {
                compactLegalButton(links[0], alignment: .leading)
                compactRestoreButton
                compactLegalButton(links[1], alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: theme.metrics.spacing.footer) {
                restoreButton

                BroadPaywallLegalFooter(
                    links: links,
                    theme: theme
                ) { link in
                    openLegalLink(link)
                }
            }
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

    var compactRestoreButton: some View {
        Button(action: viewModel.restorePurchases) {
            HStack(spacing: theme.metrics.spacing.text) {
                if viewModel.isRestoreInFlight {
                    ProgressView()
                        .tint(theme.palette.secondaryText)
                        .accessibilityHidden(true)
                }

                Text(restoreTitle)
                    .font(theme.typography.footer)
                    .foregroundStyle(theme.palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: BroadPaywallTheme.Sizing.minimumInteractiveDimension
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

    func compactLegalButton(
        _ link: BroadPaywallLegalLink,
        alignment: Alignment
    ) -> some View {
        Button {
            openLegalLink(link)
        } label: {
            Text(link.title)
                .font(theme.typography.footer)
                .foregroundStyle(theme.palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(
                    maxWidth: .infinity,
                    minHeight: BroadPaywallTheme.Sizing.minimumInteractiveDimension,
                    alignment: alignment
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
        .accessibilityLabel(Text(link.accessibilityLabel ?? link.title))
    }

    func openLegalLink(_ link: BroadPaywallLegalLink) {
        safariDestination = BroadPaywallSafariDestination(url: link.url)
    }
}
