import BroadMonetization
import BroadUIFlows
import Foundation

enum AppConfiguration {
    struct CacheFixture {
        let suiteName: String
        let namespace: String
        let keyName: String
        let schemaIdentifier: String
        let version: Int
        let timeToLive: TimeInterval
        let maximumDataSize: Int
        let value: ExampleCachedConfiguration
    }

    struct RootContent {
        let eyebrow: String
        let title: String
        let subtitle: String
        let coreDescription: String
        let monetizationDescription: String
        let uiFlowsDescription: String
        let connectedDetail: String
        let adaptyLinkedDetail: String
        let adaptyUnavailableDetail: String
        let loadingTitle: String
        let loadingMessage: String
        let readyTitle: String
        let readyMessage: String
        let degradedTitle: String
        let degradedMessage: String
        let failedTitle: String
        let retryTitle: String
    }

    static let bootstrapScenario = ExampleBootstrapScenario.current()
    static let entitlementScenario = ExampleEntitlementScenario.current()
    static let appFlowConfiguration: AppFlowConfiguration = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-app-flow-main-only") {
            return .mainOnly
        }

        if arguments.contains("-app-flow-paywall-only")
            || arguments.contains("-analytics-fixture")
            || arguments.contains("-live-adapty") {
            return AppFlowConfiguration(
                onboarding: .disabled,
                initialPaywall: .enabled(allowsClose: true)
            )
        }

        return AppFlowConfiguration(
            onboarding: .enabled,
            initialPaywall: .enabled(allowsClose: true)
        )
    }()

    static let onboardingConfiguration = OnboardingConfiguration(
        pages: [
            OnboardingPageConfiguration(
                id: "platform-foundation",
                title: "Start with a stable foundation",
                subtitle: "Bootstrap, offline cache and shared states are ready before your feature screen opens.",
                media: OnboardingMediaDescriptor(identifier: "foundation")
            ),
            OnboardingPageConfiguration(
                id: "adaptive-monetization",
                title: "Show every plan",
                subtitle: "The paywall adapts to the products returned by the provider without filtering or fixed limits.",
                media: OnboardingMediaDescriptor(identifier: "monetization")
            ),
            OnboardingPageConfiguration(
                id: "verified-access",
                title: "Unlock only verified access",
                subtitle: "Purchase and restore finish the flow only after entitlement is checked again.",
                media: OnboardingMediaDescriptor(identifier: "verified-access")
            )
        ],
        continueTitle: "Continue",
        completionTitle: "See plans",
        progressAccessibilityLabel: "Onboarding progress",
        footerLinks: [
            OnboardingFooterLinkConfiguration(
                destination: .restorePurchases,
                title: "Restore purchases"
            ),
            OnboardingFooterLinkConfiguration(
                destination: .privacyPolicy,
                title: "Privacy"
            ),
            OnboardingFooterLinkConfiguration(
                destination: .termsOfUse,
                title: "Terms"
            )
        ],
        trackingAuthorizationPolicy: ProcessInfo.processInfo.arguments.contains("-tracking-disabled")
            ? .disabled
            : .afterFirstSlide()
    )
    static let paywallConfiguration = BroadPaywallConfiguration(
        placementID: .onboarding,
        defaultSelection: .index(1),
        access: BroadPaywallAccessConfiguration(
            defaultPolicy: .soft
        ),
        legalLinks: [
            BroadPaywallLegalLink(
                id: "privacy",
                title: "Privacy",
                url: privacyPolicyURL
            ),
            BroadPaywallLegalLink(
                id: "terms",
                title: "Terms",
                url: termsOfUseURL
            )
        ]
    )
    static let privacyPolicyURL = legalURL(path: "privacy")
    static let termsOfUseURL = legalURL(path: "terms")
    static let appFlowProgressKeyPrefix: String = {
        if ProcessInfo.processInfo.arguments.contains("-analytics-fixture") {
            return "broad-app-template.app-flow.analytics-fixture"
        }
        if ProcessInfo.processInfo.arguments.contains("-live-adapty") {
            return "broad-app-template.app-flow.live-adapty"
        }
        guard let entitlementScenario else {
            return "broad-app-template.app-flow"
        }

        return "broad-app-template.app-flow.entitlement-fixture.\(entitlementScenario.rawValue)"
    }()

    static let loggingSubsystem: StaticString = "com.broadapps.platform.template"
    static let requiredServiceFailureMessage = "A required startup service is temporarily unavailable."
    static let bootstrapTimeoutMessage = "Startup took too long. Please try again."
    static let bootstrapUnknownErrorMessage = "Something went wrong. Please try again."
    static let staleCacheMessage = "The network refresh timed out. The app is using the last saved configuration."
    static let missingCacheMessage = "No saved configuration is available. Run the cache seed scenario first."
    static let invalidCacheMessage = "The saved configuration cannot be used."
    static let cacheFixture = CacheFixture(
        suiteName: "com.broadapps.platform.template.cache-fixture",
        namespace: "bootstrap-fixture",
        keyName: "configuration",
        schemaIdentifier: "broadapps.example.bootstrap-configuration",
        version: 1,
        timeToLive: 0,
        maximumDataSize: 64 * 1024,
        value: ExampleCachedConfiguration(source: "Persisted local bootstrap configuration")
    )

    private static func legalURL(path: String) -> URL {
        guard let url = URL(string: "https://example.com/\(path)") else {
            preconditionFailure("Example legal URL must be valid")
        }
        return url
    }

    static func rootContent(for scenario: ExampleBootstrapScenario) -> RootContent {
        let readyMessage: String
        let degradedMessage: String

        switch scenario {
        case .seedCache:
            readyMessage = "A local configuration snapshot was saved. Relaunch with the stale-cache scenario to verify offline fallback."
            degradedMessage = "The main route is available with reduced functionality."
        case .staleCache:
            readyMessage = "The saved configuration is still fresh."
            degradedMessage = staleCacheMessage
        case .ready, .degraded, .failedOnce:
            readyMessage = "Critical steps completed. Background services no longer block this screen."
            degradedMessage = "The main route is available, but an optional service timed out."
        }

        return RootContent(
            eyebrow: "BROADAPPS iOS PLATFORM",
            title: "A predictable app launch",
            subtitle: "Critical work is bounded by timeout. Optional services continue after the first route is available.",
            coreDescription: "Bootstrap, cache, retry, logging and shared contracts.",
            monetizationDescription: "Adapty, StoreKit, RU billing and entitlement boundaries.",
            uiFlowsDescription: "Onboarding, loader, paywall and common UI states.",
            connectedDetail: "Connected",
            adaptyLinkedDetail: "Adapty linked",
            adaptyUnavailableDetail: "Adapty unavailable",
            loadingTitle: "Starting platform",
            loadingMessage: "Running the required bootstrap steps…",
            readyTitle: "Bootstrap ready",
            readyMessage: readyMessage,
            degradedTitle: "Running in safe mode",
            degradedMessage: degradedMessage,
            failedTitle: "Startup needs attention",
            retryTitle: "Try again"
        )
    }
}

enum ExampleEntitlementScenario: String, CaseIterable, Sendable {
    case active
    case inactive
    case unknown
    case timeout
    case storeKitFallback = "store-kit-fallback"

    var launchArgument: String {
        "-entitlement-\(rawValue)"
    }

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ExampleEntitlementScenario? {
        let matches = allCases.filter { arguments.contains($0.launchArgument) }
        precondition(
            matches.count <= 1,
            "Use at most one entitlement fixture launch argument"
        )
        return matches.first
    }
}
