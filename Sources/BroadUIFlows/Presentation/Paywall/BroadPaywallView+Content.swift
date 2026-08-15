import BroadCore
import BroadMonetization
import SwiftUI

extension BroadPaywallView {
    var closeHeader: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .frame(
                    height: max(
                        theme.metrics.sizing.closeButton,
                        BroadPaywallTheme.Sizing.minimumInteractiveDimension
                    )
                )

            if viewModel.isCloseAvailable {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(theme.typography.action)
                        .foregroundStyle(theme.palette.primaryText)
                        .frame(
                            width: max(
                                theme.metrics.sizing.closeButton,
                                BroadPaywallTheme.Sizing.minimumInteractiveDimension
                            ),
                            height: max(
                                theme.metrics.sizing.closeButton,
                                BroadPaywallTheme.Sizing.minimumInteractiveDimension
                            )
                        )
                        .background(
                            Circle()
                                .fill(theme.palette.surface)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(BroadNoPressEffectButtonStyle())
                .accessibilityLabel(
                    Text(viewModel.configuration.copy.actions.closeAccessibilityLabel)
                )
            }
        }
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.top, theme.metrics.spacing.header)
    }

    var stateContent: some View {
        GeometryReader { proxy in
            ScrollView {
                stateBodyContent
                    .frame(maxWidth: .infinity)
                    .frame(
                        minHeight: proxy.size.height,
                        alignment: stateBodyAlignment
                    )
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    var stateBodyAlignment: Alignment {
        switch viewModel.state {
        case .content:
            .bottom
        case .idle, .loading, .empty, .failure:
            .center
        }
    }

    @ViewBuilder
    var stateBodyContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            messageContent {
                ProgressView()
                    .tint(theme.palette.accent)

                Text(viewModel.configuration.copy.states.loadingTitle)
                    .font(theme.typography.subtitle)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        case let .content(payload):
            productContent(payload)
        case .empty:
            emptyContent
        case let .failure(error):
            failureContent(error)
        }
    }

    var emptyContent: some View {
        messageContent {
            Text(viewModel.configuration.copy.states.emptyTitle)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.configuration.copy.states.emptyMessage)
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)

            retryButton
        }
    }

    func failureContent(_ error: AppError) -> some View {
        messageContent {
            Text(viewModel.configuration.copy.states.errorTitle)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(error.userMessage)
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)

            if error.isRetryable {
                retryButton
            }
        }
    }

    func productContent(_ payload: PaywallPayload) -> some View {
        LazyVStack(spacing: theme.metrics.spacing.content) {
            paywallHeader(payload)

            LazyVStack(spacing: theme.metrics.spacing.product) {
                ForEach(payload.products, id: \.presentationID) { product in
                    productRow(product)
                }
            }
        }
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.vertical, theme.metrics.spacing.content)
    }

    func paywallHeader(_ payload: PaywallPayload) -> some View {
        VStack(spacing: theme.metrics.spacing.text) {
            Text(viewModel.configuration.copy.header.title)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            if let subtitle = viewModel.configuration.copy.header.subtitle {
                Text(subtitle)
                    .font(theme.typography.subtitle)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if viewModel.configuration.specialOfferAuthorization?.paywallPresentationID
                == payload.presentationID,
                let specialOffer = payload.remoteConfiguration.specialOffer,
                specialOffer.isEnabled,
                !viewModel.isSpecialOfferExpired {
                BroadSpecialOfferMetadataView(
                    configuration: specialOffer,
                    countdownAuthorization: viewModel.configuration
                        .specialOfferAuthorization?.countdown,
                    copy: viewModel.configuration.specialOfferCopy,
                    theme: theme,
                    locale: productFormatter.locale
                )
            }
        }
    }

    func productRow(_ product: MonetizationProduct) -> some View {
        let copy = viewModel.configuration.copy.products
        let isEnabled = product.isEligibleForGenericPurchase
            && viewModel.canSelectProducts
        let content = BroadSelectableProductContent(
            title: product.title ?? copy.fallbackTitle,
            subtitle: product.subtitle,
            price: productFormatter.price(for: product) ?? copy.unavailablePriceTitle,
            period: productFormatter.period(for: product)
        )

        return BroadSelectableProductRow(
            product: product,
            content: content,
            isSelected: viewModel.selectedProductPresentationID == product.presentationID,
            selectedAccessibilityValue: copy.selectedAccessibilityValue,
            theme: theme
        ) {
            viewModel.selectProduct(presentationID: product.presentationID)
        }
        .allowsHitTesting(isEnabled)
        .disabled(!isEnabled)
    }

    func messageContent(
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: theme.metrics.spacing.content) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(theme.metrics.spacing.screen)
    }

    func close() {
        guard viewModel.requestClose() else {
            return
        }

        onClose()
    }
}
