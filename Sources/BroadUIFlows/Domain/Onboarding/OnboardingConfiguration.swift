import Foundation

public enum OnboardingConfigurationValidationError: Equatable, Sendable {
    case noPages
    case invalidPage
    case duplicatePageID
    case invalidActionCopy
    case duplicateFooterDestination
    case invalidFooterCopy
}

public struct OnboardingConfiguration: Equatable, Sendable {
    public let pages: [OnboardingPageConfiguration]
    public let continueTitle: String
    public let completionTitle: String
    public let progressAccessibilityLabel: String
    public let footerLinks: [OnboardingFooterLinkConfiguration]
    public let trackingAuthorizationPolicy: OnboardingTrackingAuthorizationPolicy

    /// Invalid app/remote configuration is represented as data. The renderer
    /// safely skips such an onboarding and never schedules ATT instead of
    /// terminating the process with a precondition failure.
    public let validationError: OnboardingConfigurationValidationError?

    public var isValid: Bool {
        validationError == nil
    }

    public init(
        pages: [OnboardingPageConfiguration],
        continueTitle: String,
        completionTitle: String,
        progressAccessibilityLabel: String,
        footerLinks: [OnboardingFooterLinkConfiguration] = [],
        trackingAuthorizationPolicy: OnboardingTrackingAuthorizationPolicy = .disabled
    ) {
        self.pages = pages
        self.continueTitle = continueTitle
        self.completionTitle = completionTitle
        self.progressAccessibilityLabel = progressAccessibilityLabel
        self.footerLinks = footerLinks
        self.trackingAuthorizationPolicy = trackingAuthorizationPolicy
        validationError = Self.validate(
            pages: pages,
            continueTitle: continueTitle,
            completionTitle: completionTitle,
            progressAccessibilityLabel: progressAccessibilityLabel,
            footerLinks: footerLinks
        )
    }
}

private extension OnboardingConfiguration {
    static func validate(
        pages: [OnboardingPageConfiguration],
        continueTitle: String,
        completionTitle: String,
        progressAccessibilityLabel: String,
        footerLinks: [OnboardingFooterLinkConfiguration]
    ) -> OnboardingConfigurationValidationError? {
        guard !pages.isEmpty else {
            return .noPages
        }
        guard pages.allSatisfy(\.isValid) else {
            return .invalidPage
        }
        guard Set(pages.map(\.id)).count == pages.count else {
            return .duplicatePageID
        }
        guard [continueTitle, completionTitle, progressAccessibilityLabel].allSatisfy(\.isNonBlank) else {
            return .invalidActionCopy
        }
        guard Set(footerLinks.map(\.destination)).count == footerLinks.count else {
            return .duplicateFooterDestination
        }
        guard footerLinks.allSatisfy(\.title.isNonBlank) else {
            return .invalidFooterCopy
        }
        return nil
    }
}

private extension String {
    var isNonBlank: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
