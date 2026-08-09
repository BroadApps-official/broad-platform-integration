import Foundation

public struct OnboardingTrackingAuthorizationPolicy: Equatable, Sendable {
    public let requestDelay: Duration?

    private init(requestDelay: Duration?) {
        self.requestDelay = requestDelay
    }

    public static let disabled = OnboardingTrackingAuthorizationPolicy(
        requestDelay: nil
    )

    public static func afterFirstSlide(
        delay: Duration = .milliseconds(400)
    ) -> OnboardingTrackingAuthorizationPolicy {
        // A non-positive value can arrive from app-owned or remote configuration.
        // Fail closed instead of crashing or requesting before the first slide has
        // had a chance to become visibly rendered.
        guard delay > .zero else {
            return .disabled
        }

        return OnboardingTrackingAuthorizationPolicy(requestDelay: delay)
    }
}
