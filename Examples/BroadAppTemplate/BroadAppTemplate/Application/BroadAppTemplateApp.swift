import BroadUIFlows
import SwiftUI

@main
struct BroadAppTemplateApp: App {
    private let compositionRoot = AppCompositionRoot()

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-ru-payment-sheet") {
                ExampleRUPaymentSheetFixtureView(initialMethod: .sbp)
            } else if ProcessInfo.processInfo.arguments.contains(
                "-ru-payment-sheet-apple"
            ) {
                ExampleRUPaymentSheetFixtureView(initialMethod: .apple)
            } else if ProcessInfo.processInfo.arguments.contains(
                "-ru-subscription-management"
            ) || ProcessInfo.processInfo.arguments.contains(
                "-ru-subscription-cancelled"
            ) {
                BroadRUSubscriptionManagementView(
                    viewModel: compositionRoot.ruSubscriptionViewModel,
                    copy: .russian,
                    theme: AppTokens.paywallTheme
                )
            } else {
                AppFlowRootView(
                    coordinator: compositionRoot.appFlowCoordinator,
                    sceneViewModel: compositionRoot.appFlowSceneViewModel,
                    onboardingViewModel: compositionRoot.onboardingViewModel,
                    paywallViewModel: compositionRoot.paywallViewModel,
                    rootViewModel: compositionRoot.rootViewModel,
                    analyticsViewModel: compositionRoot.analyticsViewModel
                )
            }
        }
    }
}
