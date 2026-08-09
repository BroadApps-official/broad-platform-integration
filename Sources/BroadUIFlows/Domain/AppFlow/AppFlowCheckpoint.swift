public enum AppFlowCheckpoint: Equatable, Sendable {
    case start
    case onboardingCompleted
    case initialPaywallResolved

    public var hasCompletedOnboarding: Bool {
        switch self {
        case .start:
            false
        case .onboardingCompleted, .initialPaywallResolved:
            true
        }
    }

    public var hasResolvedInitialPaywall: Bool {
        self == .initialPaywallResolved
    }
}
