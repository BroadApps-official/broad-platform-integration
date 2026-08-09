import SwiftUI

@main
struct BroadAppTemplateApp: App {
    private let compositionRoot = AppCompositionRoot()

    var body: some Scene {
        WindowGroup {
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
