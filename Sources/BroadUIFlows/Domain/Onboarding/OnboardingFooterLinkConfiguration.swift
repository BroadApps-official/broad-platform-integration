public enum OnboardingFooterDestination: Equatable, Hashable, Sendable {
    case privacyPolicy
    case restorePurchases
    case termsOfUse
}

public struct OnboardingFooterLinkConfiguration: Identifiable, Equatable, Sendable {
    public let destination: OnboardingFooterDestination
    public let title: String
    public let accessibilityLabel: String?

    public var id: OnboardingFooterDestination {
        destination
    }

    public init(
        destination: OnboardingFooterDestination,
        title: String,
        accessibilityLabel: String? = nil
    ) {
        self.destination = destination
        self.title = title
        self.accessibilityLabel = accessibilityLabel
    }
}
