import SwiftUI

@MainActor
public struct BroadAppFlowView<
    LaunchContent: View,
    OnboardingContent: View,
    PaywallContent: View,
    MainContent: View
>: View {
    private let route: AppFlowRoute
    private let launch: @MainActor () -> LaunchContent
    private let onboarding: @MainActor () -> OnboardingContent
    private let initialPaywall: @MainActor () -> PaywallContent
    private let main: @MainActor () -> MainContent

    public init(
        route: AppFlowRoute,
        @ViewBuilder launch: @escaping @MainActor () -> LaunchContent,
        @ViewBuilder onboarding: @escaping @MainActor () -> OnboardingContent,
        @ViewBuilder initialPaywall: @escaping @MainActor () -> PaywallContent,
        @ViewBuilder main: @escaping @MainActor () -> MainContent
    ) {
        self.route = route
        self.launch = launch
        self.onboarding = onboarding
        self.initialPaywall = initialPaywall
        self.main = main
    }

    public var body: some View {
        switch route {
        case .launch:
            launch()
        case .onboarding:
            onboarding()
        case .initialPaywall:
            initialPaywall()
        case .main:
            main()
        @unknown default:
            launch()
        }
    }
}
