import BroadMonetization

public struct AppFlowStateMachine: Sendable {
    public private(set) var route: AppFlowRoute = .launch

    private let configuration: AppFlowConfiguration

    public init(configuration: AppFlowConfiguration) {
        self.configuration = configuration
    }

    @discardableResult
    public mutating func resolve(
        checkpoint: AppFlowCheckpoint,
        entitlementStatus: EntitlementStatus?
    ) -> AppFlowRoute {
        guard route != .main else {
            return route
        }

        if configuration.onboarding == .enabled, !checkpoint.hasCompletedOnboarding {
            route = .onboarding
            return route
        }

        if configuration.initialPaywall == .disabled
            || configuration.honorsResolvedInitialPaywallCheckpoint
            && checkpoint.hasResolvedInitialPaywall {
            route = .main
            return route
        }

        guard let entitlementStatus else {
            route = .launch
            return route
        }

        switch entitlementStatus {
        case .active:
            route = .main
        case .inactive:
            route = .initialPaywall
        case .unknown:
            route = .main
        }

        return route
    }

    @discardableResult
    public mutating func subscriptionDidBecomeActive() -> AppFlowRoute {
        if route == .initialPaywall {
            route = .main
        }

        return route
    }

    @discardableResult
    public mutating func initialPaywallDismissed() -> AppFlowRoute {
        if route == .initialPaywall, configuration.allowsInitialPaywallClose {
            route = .main
        }

        return route
    }

    @discardableResult
    public mutating func initialPaywallUnavailable() -> AppFlowRoute {
        if route == .initialPaywall {
            route = .main
        }

        return route
    }

    @discardableResult
    public mutating func restart() -> AppFlowRoute {
        route = .launch
        return route
    }
}
