public enum AppFlowStepPolicy: Equatable, Sendable {
    case disabled
    case enabled
}

public enum AppFlowInitialPaywallPolicy: Equatable, Sendable {
    case disabled
    case onceAfterOnboarding(allowsClose: Bool)
    case everyColdLaunchWhileInactive(allowsClose: Bool)
}

public struct AppFlowConfiguration: Equatable, Sendable {
    public let onboarding: AppFlowStepPolicy
    public let initialPaywall: AppFlowInitialPaywallPolicy

    public init(
        onboarding: AppFlowStepPolicy,
        initialPaywall: AppFlowInitialPaywallPolicy
    ) {
        self.onboarding = onboarding
        self.initialPaywall = initialPaywall
    }

    public static let mainOnly = AppFlowConfiguration(
        onboarding: .disabled,
        initialPaywall: .disabled
    )

    public var requiresStoredProgress: Bool {
        onboarding == .enabled || initialPaywall != .disabled
    }

    public var allowsInitialPaywallClose: Bool {
        switch initialPaywall {
        case .disabled:
            false
        case let .onceAfterOnboarding(allowsClose),
             let .everyColdLaunchWhileInactive(allowsClose):
            allowsClose
        }
    }

    var persistsInitialPaywallResolution: Bool {
        if case .onceAfterOnboarding = initialPaywall {
            return true
        }

        return false
    }

    var honorsResolvedInitialPaywallCheckpoint: Bool {
        persistsInitialPaywallResolution
    }
}
