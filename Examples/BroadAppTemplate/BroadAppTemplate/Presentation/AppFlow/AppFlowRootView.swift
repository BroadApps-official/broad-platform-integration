import BroadUIFlows
import Foundation
import SwiftUI

struct AppFlowRootView: View {
    @ObservedObject private var coordinator: AppFlowCoordinator
    @StateObject private var sceneViewModel: AppFlowSceneViewModel

    private let onboardingViewModel: OnboardingViewModel
    private let paywallViewModel: PaywallViewModel
    private let rootViewModel: RootViewModel
    private let analyticsViewModel: ExampleAnalyticsViewModel

    init(
        coordinator: AppFlowCoordinator,
        sceneViewModel: AppFlowSceneViewModel,
        onboardingViewModel: OnboardingViewModel,
        paywallViewModel: PaywallViewModel,
        rootViewModel: RootViewModel,
        analyticsViewModel: ExampleAnalyticsViewModel
    ) {
        self.coordinator = coordinator
        _sceneViewModel = StateObject(wrappedValue: sceneViewModel)
        self.onboardingViewModel = onboardingViewModel
        self.paywallViewModel = paywallViewModel
        self.rootViewModel = rootViewModel
        self.analyticsViewModel = analyticsViewModel
    }

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

    private func onboardingContent() -> some View {
        BroadOnboardingView(
            viewModel: onboardingViewModel,
            media: ExampleOnboardingMediaView.init,
            onFooterAction: sceneViewModel.onboardingFooterAction,
            onCompleted: sceneViewModel.onboardingCompleted
        )
    }

    private func paywallContent() -> some View {
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

    private func mainContent() -> some View {
        ExampleMainView(
            rootViewModel: rootViewModel,
            analyticsViewModel: analyticsViewModel
        )
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
        return "route=\(coordinator.route.accessibilityValue);fixture=\(fixture)"
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
