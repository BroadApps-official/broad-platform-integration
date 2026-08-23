import BroadUIFlows
import Foundation
import SwiftUI

struct AppFlowRootView: View {
    @ObservedObject private var coordinator: AppFlowCoordinator
    @StateObject private var sceneViewModel: AppFlowSceneViewModel

    private let onboardingViewModel: OnboardingViewModel
    private let paywallViewModel: PaywallViewModel
    private let catalogSpecialOfferViewModel: ExampleSpecialOfferFixtureViewModel
    private let tokenPaywallViewModel: BroadTokenPaywallViewModel
    private let tokenBalanceViewModel: ExampleTokenBalanceViewModel
    private let rootViewModel: RootViewModel
    private let analyticsViewModel: ExampleAnalyticsViewModel
    #if DEBUG
        private let debugSettingsViewModel: ExampleDebugSettingsViewModel
    #endif

    #if DEBUG
        init(
            coordinator: AppFlowCoordinator,
            sceneViewModel: AppFlowSceneViewModel,
            onboardingViewModel: OnboardingViewModel,
            paywallViewModel: PaywallViewModel,
            catalogSpecialOfferViewModel: ExampleSpecialOfferFixtureViewModel,
            tokenPaywallViewModel: BroadTokenPaywallViewModel,
            tokenBalanceViewModel: ExampleTokenBalanceViewModel,
            rootViewModel: RootViewModel,
            analyticsViewModel: ExampleAnalyticsViewModel,
            debugSettingsViewModel: ExampleDebugSettingsViewModel
        ) {
            self.coordinator = coordinator
            _sceneViewModel = StateObject(wrappedValue: sceneViewModel)
            self.onboardingViewModel = onboardingViewModel
            self.paywallViewModel = paywallViewModel
            self.catalogSpecialOfferViewModel = catalogSpecialOfferViewModel
            self.tokenPaywallViewModel = tokenPaywallViewModel
            self.tokenBalanceViewModel = tokenBalanceViewModel
            self.rootViewModel = rootViewModel
            self.analyticsViewModel = analyticsViewModel
            self.debugSettingsViewModel = debugSettingsViewModel
        }
    #else
        init(
            coordinator: AppFlowCoordinator,
            sceneViewModel: AppFlowSceneViewModel,
            onboardingViewModel: OnboardingViewModel,
            paywallViewModel: PaywallViewModel,
            catalogSpecialOfferViewModel: ExampleSpecialOfferFixtureViewModel,
            tokenPaywallViewModel: BroadTokenPaywallViewModel,
            tokenBalanceViewModel: ExampleTokenBalanceViewModel,
            rootViewModel: RootViewModel,
            analyticsViewModel: ExampleAnalyticsViewModel
        ) {
            self.coordinator = coordinator
            _sceneViewModel = StateObject(wrappedValue: sceneViewModel)
            self.onboardingViewModel = onboardingViewModel
            self.paywallViewModel = paywallViewModel
            self.catalogSpecialOfferViewModel = catalogSpecialOfferViewModel
            self.tokenPaywallViewModel = tokenPaywallViewModel
            self.tokenBalanceViewModel = tokenBalanceViewModel
            self.rootViewModel = rootViewModel
            self.analyticsViewModel = analyticsViewModel
        }
    #endif

    var body: some View {
        BroadAppFlowView(
            route: coordinator.route,
            launch: launchContent,
            onboarding: onboardingContent,
            initialPaywall: paywallContent,
            main: mainContent
        )
        .accessibilityIdentifier("broadapps.app-flow.root")
        .accessibilityValue(accessibilityValue)
        .sheet(isPresented: legalPageBinding) {
            if let url = sceneViewModel.legalURL {
                BroadInAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .alert(item: $sceneViewModel.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func launchContent() -> some View {
        RootView(viewModel: rootViewModel)
    }

    @ViewBuilder
    private func onboardingContent() -> some View {
        if AppConfiguration.onboardingScenario.usesCustomRenderer {
            ExampleCustomOnboardingView(
                viewModel: onboardingViewModel,
                onFooterAction: sceneViewModel.onboardingFooterAction,
                onCompleted: sceneViewModel.onboardingCompleted
            )
        } else {
            BroadOnboardingView(
                viewModel: onboardingViewModel,
                media: ExampleOnboardingMediaView.init,
                onFooterAction: sceneViewModel.onboardingFooterAction,
                onCompleted: sceneViewModel.onboardingCompleted
            )
        }
    }

    @ViewBuilder
    private func paywallContent() -> some View {
        if sceneViewModel.isResolvingSpecialOffer {
            specialOfferResolutionProgress
        } else if let specialOfferViewModel = sceneViewModel.activeSpecialOfferViewModel {
            ExampleSpecialOfferFixtureView(
                viewModel: specialOfferViewModel,
                onClose: sceneViewModel.specialOfferClosed,
                onCompleted: sceneViewModel.paywallCompleted
            )
        } else {
            BroadPaywallView(
                viewModel: paywallViewModel,
                theme: AppTokens.paywallTheme,
                productFormatter: BroadPaywallProductFormatter(
                    locale: Locale(identifier: "ru_RU"),
                    periodCopy: .russian
                ),
                onClose: sceneViewModel.paywallClosed,
                onCompleted: sceneViewModel.paywallCompleted
            )
        }
    }

    private var specialOfferResolutionProgress: some View {
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
        .accessibilityIdentifier("special-offer.resolving")
    }

    private func mainContent() -> some View {
        #if DEBUG
            ExampleMainView(
                rootViewModel: rootViewModel,
                paywallViewModel: paywallViewModel,
                specialOfferViewModel: catalogSpecialOfferViewModel,
                tokenPaywallViewModel: tokenPaywallViewModel,
                tokenBalanceViewModel: tokenBalanceViewModel,
                analyticsViewModel: analyticsViewModel,
                debugSettingsViewModel: debugSettingsViewModel
            )
        #else
            ExampleMainView(
                rootViewModel: rootViewModel,
                paywallViewModel: paywallViewModel,
                specialOfferViewModel: catalogSpecialOfferViewModel,
                tokenPaywallViewModel: tokenPaywallViewModel,
                tokenBalanceViewModel: tokenBalanceViewModel,
                analyticsViewModel: analyticsViewModel
            )
        #endif
    }

    private var legalPageBinding: Binding<Bool> {
        Binding(
            get: { sceneViewModel.legalURL != nil },
            set: { isPresented in
                if !isPresented {
                    sceneViewModel.closeLegalPage()
                }
            }
        )
    }

    private var accessibilityValue: String {
        let fixture = AppConfiguration.entitlementScenario?.rawValue ?? "default"
        return "route=\(coordinator.route.accessibilityValue);presentation=\(presentationValue);fixture=\(fixture)"
    }

    private var presentationValue: String {
        guard coordinator.route == .initialPaywall else {
            return coordinator.route.accessibilityValue
        }
        if sceneViewModel.isResolvingSpecialOffer {
            return "special-offer-resolver"
        }
        if sceneViewModel.activeSpecialOfferViewModel != nil {
            return "special-offer"
        }
        return "subscription-paywall"
    }
}

private extension AppFlowRoute {
    var accessibilityValue: String {
        switch self {
        case .launch:
            "launch"
        case .onboarding:
            "onboarding"
        case .initialPaywall:
            "initial-paywall"
        case .main:
            "main"
        @unknown default:
            "unknown"
        }
    }
}
