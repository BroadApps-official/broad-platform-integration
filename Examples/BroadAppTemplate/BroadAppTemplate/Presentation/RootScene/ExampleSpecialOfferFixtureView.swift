import BroadUIFlows
import SwiftUI

@MainActor
struct ExampleSpecialOfferCatalogFlowView: View {
    private enum Phase: Equatable {
        case subscriptionPaywall
        case resolvingOffer
        case specialOffer

        var accessibilityValue: String {
            switch self {
            case .subscriptionPaywall: "subscription-paywall"
            case .resolvingOffer: "resolving-offer"
            case .specialOffer: "special-offer"
            }
        }
    }

    @ObservedObject var subscriptionPaywallViewModel: PaywallViewModel
    @ObservedObject var specialOfferViewModel: ExampleSpecialOfferFixtureViewModel

    @State private var phase = Phase.subscriptionPaywall
    @State private var resolutionTask: Task<Void, Never>?
    @State private var hasPreparedOffer = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch phase {
            case .subscriptionPaywall:
                BroadPaywallView(
                    viewModel: subscriptionPaywallViewModel,
                    theme: AppTokens.paywallTheme,
                    productFormatter: BroadPaywallProductFormatter(),
                    onClose: subscriptionPaywallClosed,
                    onCompleted: { _ in dismiss() }
                )
            case .resolvingOffer:
                resolutionProgress
            case .specialOffer:
                ExampleSpecialOfferFixtureView(
                    viewModel: specialOfferViewModel,
                    onClose: { dismiss() },
                    onCompleted: { _ in dismiss() }
                )
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("catalog.special-offer-flow")
        .accessibilityValue(phase.accessibilityValue)
        .onAppear {
            guard !hasPreparedOffer else {
                return
            }
            hasPreparedOffer = true
            specialOfferViewModel.resetForCatalogPresentation()
        }
        .onDisappear {
            resolutionTask?.cancel()
            resolutionTask = nil
        }
    }

    private var resolutionProgress: some View {
        ZStack {
            AppTokens.Color.background.ignoresSafeArea()
            VStack(spacing: AppTokens.Spacing.cardContent) {
                ProgressView()
                    .tint(AppTokens.Color.accent)
                Text("Проверяем специальное предложение…")
                    .font(AppTokens.Font.body)
                    .foregroundStyle(AppTokens.Color.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("catalog.special-offer.resolving")
    }

    private func subscriptionPaywallClosed() {
        guard phase == .subscriptionPaywall, resolutionTask == nil else {
            return
        }

        phase = .resolvingOffer
        resolutionTask = Task { @MainActor in
            let shouldPresent = await specialOfferViewModel.resolveIfNeeded()
            guard !Task.isCancelled else {
                return
            }

            resolutionTask = nil
            if shouldPresent {
                phase = .specialOffer
            } else {
                dismiss()
            }
        }
    }
}

@MainActor
struct ExampleSpecialOfferFixtureView: View {
    @ObservedObject var viewModel: ExampleSpecialOfferFixtureViewModel
    var onClose: () -> Void = {}
    var onCompleted: (BroadPaywallCompletion) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let paywallViewModel = viewModel.paywallViewModel {
                BroadPaywallView(
                    viewModel: paywallViewModel,
                    theme: AppTokens.paywallTheme,
                    productFormatter: BroadPaywallProductFormatter(),
                    onClose: close,
                    onCompleted: completed
                )
            } else {
                statusView
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func close() {
        onClose()
        dismiss()
    }

    private func completed(_ completion: BroadPaywallCompletion) {
        viewModel.confirmedPurchaseOrRestore()
        onCompleted(completion)
        dismiss()
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
