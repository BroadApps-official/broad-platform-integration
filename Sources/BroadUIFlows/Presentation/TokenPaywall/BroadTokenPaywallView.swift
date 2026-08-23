import BroadCore
import BroadMonetization
import Foundation
import SwiftUI

@MainActor
public struct BroadTokenPaywallView: View {
    @ObservedObject var viewModel: BroadTokenPaywallViewModel
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let theme: BroadPaywallTheme
    let productFormatter: BroadPaywallProductFormatter
    let onClose: @MainActor () -> Void

    public init(
        viewModel: BroadTokenPaywallViewModel,
        theme: BroadPaywallTheme,
        productFormatter: BroadPaywallProductFormatter = BroadPaywallProductFormatter(),
        onClose: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.theme = theme
        self.productFormatter = productFormatter
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            theme.palette.background
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    closeHeader
                    stateContent
                    actionFooter
                }
                .frame(
                    maxWidth: theme.metrics.sizing.maximumContentWidth,
                    maxHeight: .infinity
                )
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            viewModel.viewDidAppear()
        }
    }
}

extension BroadTokenPaywallView {
    var copy: BroadTokenPaywallCopy {
        viewModel.configuration.copy
    }

    var originAccessibilityValue: String {
        guard let payload = viewModel.state.payload else {
            return "catalog=unresolved"
        }
        return "requested=\(payload.origin.requestedPlacementID.rawValue);"
            + "resolved=\(payload.origin.resolvedPlacementID.rawValue)"
    }

    var closeHeader: some View {
        HStack {
            Spacer()
            Button {
                guard !viewModel.isBusy else {
                    return
                }
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(theme.typography.action)
                    .foregroundStyle(theme.palette.primaryText)
                    .frame(
                        width: theme.metrics.sizing.closeButton,
                        height: theme.metrics.sizing.closeButton
                    )
                    .background(Circle().fill(theme.palette.surface))
                    .contentShape(Rectangle())
            }
            .buttonStyle(BroadNoPressEffectButtonStyle())
            .disabled(viewModel.isBusy)
            .accessibilityLabel(copy.actions.closeAccessibilityLabel)
        }
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.top, theme.metrics.spacing.header)
    }

    var stateContent: some View {
        ScrollView {
            VStack(spacing: theme.metrics.spacing.content) {
                switch viewModel.state {
                case .idle, .loading:
                    loadingContent
                case let .content(payload):
                    productContent(payload)
                case .empty:
                    emptyContent
                case let .failure(error):
                    failureContent(error)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, theme.metrics.spacing.screen)
            .padding(.vertical, theme.metrics.spacing.content)
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 360,
                alignment: .center
            )
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    var loadingContent: some View {
        Group {
            ProgressView()
                .tint(theme.palette.accent)
            Text(copy.states.loadingTitle)
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    var emptyContent: some View {
        Group {
            Text(copy.states.emptyTitle)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.center)
            Text(copy.states.emptyMessage)
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)
            retryLoadButton
        }
    }

    func failureContent(_ error: AppError) -> some View {
        Group {
            Text(copy.states.errorTitle)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)
                .multilineTextAlignment(.center)
            Text(error.userMessage)
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)
            if error.isRetryable {
                retryLoadButton
            }
        }
    }

    func productContent(_ paywall: PaywallPayload) -> some View {
        VStack(spacing: theme.metrics.spacing.content) {
            VStack(spacing: theme.metrics.spacing.text) {
                Text(copy.header.title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.palette.primaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("broad-token-paywall.root")
                    .accessibilityValue(originAccessibilityValue)
                Text(copy.header.subtitle)
                    .font(theme.typography.subtitle)
                    .foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.center)
            }

            balanceCard

            LazyVStack(spacing: theme.metrics.spacing.product) {
                ForEach(paywall.products, id: \.presentationID) { product in
                    productRow(product)
                }
            }

            feedbackContent
            analyticsContent
        }
    }

    var balanceCard: some View {
        HStack(spacing: theme.metrics.spacing.productContent) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(theme.typography.productPrice)
                .foregroundStyle(theme.palette.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
                Text(copy.header.balanceTitle)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
                Text(balanceText)
                    .font(theme.typography.productPrice)
                    .foregroundStyle(theme.palette.primaryText)
            }

            Spacer(minLength: 0)

            if viewModel.isRecoveringAccountBalance {
                ProgressView()
                    .tint(theme.palette.accent)
            }
        }
        .padding(theme.metrics.spacing.productContent)
        .background(theme.palette.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: theme.metrics.sizing.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("broad-token-paywall.balance")
    }

    func productRow(_ product: MonetizationProduct) -> some View {
        BroadSelectableProductRow(
            product: product,
            content: BroadSelectableProductContent(
                title: product.title ?? copy.products.fallbackTitle,
                subtitle: product.subtitle,
                price: productFormatter.price(for: product)
                    ?? copy.products.unavailablePriceTitle,
                period: nil
            ),
            isSelected: viewModel.selectedProductPresentationID == product.presentationID,
            selectedAccessibilityValue: copy.products.selectedAccessibilityValue,
            theme: theme
        ) {
            viewModel.selectProduct(presentationID: product.presentationID)
        }
        .allowsHitTesting(product.isTokenPackage && viewModel.canSelectProducts)
        .disabled(!product.isTokenPackage || !viewModel.canSelectProducts)
        .accessibilityIdentifier(
            "broad-token-paywall-product-\(product.presentationID.rawValue)"
        )
    }

    @ViewBuilder
    var feedbackContent: some View {
        if let feedback = viewModel.feedback {
            VStack(spacing: theme.metrics.spacing.text) {
                Image(systemName: feedback.systemImage)
                    .font(theme.typography.productPrice)
                    .foregroundStyle(feedback.tint(theme: theme))
                    .accessibilityHidden(true)
                Text(feedbackMessage(feedback))
                    .font(theme.typography.subtitle)
                    .foregroundStyle(theme.palette.primaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.metrics.spacing.productContent)
            .background(theme.palette.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: theme.metrics.sizing.cornerRadius,
                    style: .continuous
                )
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("broad-token-paywall.feedback")
        }
    }

    var analyticsContent: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
            Text(copy.analytics.title)
                .font(theme.typography.productTitle)
                .foregroundStyle(theme.palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.analyticsRecords.isEmpty {
                Text(copy.analytics.emptyMessage)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
            } else {
                ForEach(viewModel.analyticsRecords.suffix(6).reversed()) { record in
                    Text(record.event.rawValue)
                        .font(theme.typography.productDetail)
                        .foregroundStyle(theme.palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.metrics.spacing.productContent)
        .background(theme.palette.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: theme.metrics.sizing.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityIdentifier("broad-token-paywall.analytics")
    }

    @ViewBuilder
    var actionFooter: some View {
        if case .content = viewModel.state {
            VStack(spacing: theme.metrics.spacing.text) {
                BroadPaywallPrimaryButton(
                    title: primaryActionTitle,
                    isEnabled: primaryActionIsEnabled,
                    isInFlight: viewModel.isPurchaseInFlight
                        || viewModel.isRecoveringPendingPurchase,
                    theme: theme,
                    action: primaryAction
                )
                .accessibilityIdentifier("broad-token-paywall.primary-action")

                Button {
                    viewModel.recoverAccountBalance()
                } label: {
                    HStack(spacing: theme.metrics.spacing.text) {
                        if viewModel.isRecoveringAccountBalance {
                            ProgressView()
                                .tint(theme.palette.accent)
                        }
                        Text(
                            viewModel.isRecoveringAccountBalance
                                ? copy.actions.recoveringBalanceTitle
                                : copy.actions.recoverBalanceTitle
                        )
                        .font(theme.typography.footer)
                        .foregroundStyle(theme.palette.secondaryText)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: BroadPaywallTheme.Sizing.minimumInteractiveDimension
                    )
                }
                .buttonStyle(BroadNoPressEffectButtonStyle())
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier("broad-token-paywall.recover-balance")
            }
            .padding(.horizontal, theme.metrics.spacing.screen)
            .padding(.vertical, theme.metrics.spacing.footer)
            .background(theme.palette.background)
        }
    }

    var retryLoadButton: some View {
        Button(copy.actions.retryTitle) {
            viewModel.retryLoad()
        }
        .font(theme.typography.action)
        .foregroundStyle(theme.palette.accent)
        .frame(
            minWidth: BroadPaywallTheme.Sizing.minimumInteractiveDimension,
            minHeight: BroadPaywallTheme.Sizing.minimumInteractiveDimension
        )
    }
}
