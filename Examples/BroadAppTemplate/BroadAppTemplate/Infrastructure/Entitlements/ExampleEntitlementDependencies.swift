import BroadCore
import BroadMonetization
import Dispatch
import Foundation

struct ExampleEntitlementDependencies {
    private static let maximumEncodedSize = 16 * 1024

    let engine: EntitlementEngine

    init(
        scenario: ExampleEntitlementScenario,
        logger: any BroadLoggerProtocol,
        analytics: any MonetizationAnalyticsProtocol
    ) {
        let clock = CacheClock.system
        let subject = EntitlementSubject.anonymous
        let entitlementCache = Self.makeEntitlementCache(
            scenario: scenario,
            logger: logger,
            clock: clock
        )
        let registration = Self.makeAppleRegistration(
            scenario: scenario,
            subject: subject,
            clock: clock
        )

        engine = EntitlementEngine(
            registrations: [registration],
            subject: subject,
            cache: entitlementCache,
            timeoutPolicy: .seconds(0.25),
            clock: clock,
            analytics: analytics
        )
    }

    private static func makeEntitlementCache(
        scenario: ExampleEntitlementScenario,
        logger: any BroadLoggerProtocol,
        clock: CacheClock
    ) -> VersionedEntitlementCache {
        let keyValueStore = UserDefaultsKeyValueStore(
            suiteName: "com.broadapps.platform.template.entitlement-fixture",
            namespace: "entitlement-source-v1.\(scenario.rawValue)",
            maximumDataSize: Self.maximumEncodedSize
        )
        let cacheRepository = VersionedJSONCacheRepository(
            keyValueStore: keyValueStore,
            clock: clock,
            maximumEncodedSize: Self.maximumEncodedSize,
            logger: logger
        )
        return VersionedEntitlementCache(
            repository: cacheRepository,
            clock: clock
        )
    }

    private static func makeAppleRegistration(
        scenario: ExampleEntitlementScenario,
        subject: EntitlementSubject,
        clock: CacheClock
    ) -> EntitlementSourceRegistration {
        let adaptyVerifier = makeAdaptyVerifier(
            scenario: scenario,
            subject: subject,
            clock: clock
        )
        return AppleEntitlementSourceFactory(
            storeKitClient: ExampleStoreKitEntitlementsClient(
                scenario: scenario,
                clock: clock
            ),
            clock: clock
        ).makeRegistration(
            configuration: makeAppleConfiguration(
                subject: subject
            ),
            additionalAuthoritativeVerifiers: [adaptyVerifier]
        )
    }

    private static func makeAdaptyVerifier(
        scenario: ExampleEntitlementScenario,
        subject: EntitlementSubject,
        clock: CacheClock
    ) -> AdaptyAppleEntitlementVerifier {
        AdaptyAppleEntitlementVerifier(
            configuration: AdaptyAppleEntitlementConfiguration(
                subject: subject,
                accessLevelIdentifier: ExampleAppleEntitlementFixture.accessLevelIdentifier
            ),
            client: ExampleAdaptyEntitlementProfileClient(
                scenario: scenario,
                clock: clock
            ),
            clock: clock
        )
    }

    private static func makeAppleConfiguration(
        subject: EntitlementSubject
    ) -> AppleEntitlementSourceConfiguration {
        AppleEntitlementSourceConfiguration(
            subject: subject,
            freshnessPolicy: EntitlementFreshnessPolicy(
                timeToLive: 60,
                offlineActiveGrace: 300
            ),
            appBundleIdentifier: ExampleAppleEntitlementFixture.appBundleIdentifier,
            productCatalog: ApplePremiumProductCatalog(
                entries: [
                    ApplePremiumProductCatalog.Entry(
                        productID: ExampleAppleEntitlementFixture.premiumProductID,
                        kind: .autoRenewable
                    )
                ]
            ),
            ownershipPolicy: .appStoreAccount
        )
    }
}

private enum ExampleAppleEntitlementFixture {
    static let accessLevelIdentifier = "fixture-premium"
    static let appBundleIdentifier = "com.broadapps.platform.template"
    static let premiumProductID = "fixture.premium.subscription"
    private static let activeDuration: TimeInterval = 3600
    private static let timeoutDelayMilliseconds = 1500

    static func expirationDate(clock: CacheClock) -> Date {
        clock.now().addingTimeInterval(activeDuration)
    }

    static var timeoutDelay: Int {
        timeoutDelayMilliseconds
    }
}

private struct ExampleAdaptyEntitlementProfileClient: AdaptyEntitlementProfileClientProtocol {
    let scenario: ExampleEntitlementScenario
    let clock: CacheClock

    func loadProfile(
        for subject: EntitlementSubject
    ) async -> AdaptyEntitlementProfileResult {
        guard subject == .anonymous else {
            return .unresolved
        }

        switch scenario {
        case .active:
            return .serverValidated(profile(subject: subject, isActive: true))
        case .inactive:
            return .serverValidated(profile(subject: subject, isActive: false))
        case .unknown, .storeKitFallback:
            return .unqualified(profile(subject: subject, isActive: true))
        case .timeout:
            await ExampleEntitlementDelay.waitIgnoringCancellation(
                milliseconds: ExampleAppleEntitlementFixture.timeoutDelay
            )
            return .serverValidated(profile(subject: subject, isActive: true))
        }
    }

    private func profile(
        subject: EntitlementSubject,
        isActive: Bool
    ) -> AdaptyEntitlementProfileSnapshot {
        AdaptyEntitlementProfileSnapshot(
            subject: subject,
            accessLevels: [
                ExampleAppleEntitlementFixture.accessLevelIdentifier: AdaptyEntitlementAccessLevelSnapshot(
                    identifier: ExampleAppleEntitlementFixture.accessLevelIdentifier,
                    isActive: isActive,
                    expiresAt: isActive
                        ? ExampleAppleEntitlementFixture.expirationDate(clock: clock)
                        : nil,
                    isLifetime: false,
                    isInGracePeriod: false,
                    startsAt: nil,
                    isRefund: false
                )
            ]
        )
    }
}

private struct ExampleStoreKitEntitlementsClient: StoreKitEntitlementsClientProtocol {
    let scenario: ExampleEntitlementScenario
    let clock: CacheClock

    func currentEntitlements(
        for productIDs: Set<String>
    ) async -> [StoreKitCurrentEntitlementRecord] {
        guard
            scenario == .storeKitFallback,
            productIDs.contains(ExampleAppleEntitlementFixture.premiumProductID)
        else {
            return []
        }

        return [
            .verified(
                StoreKitCurrentEntitlementRecord.Verified(
                    productID: ExampleAppleEntitlementFixture.premiumProductID,
                    appBundleID: ExampleAppleEntitlementFixture.appBundleIdentifier,
                    productKind: .autoRenewable,
                    purchaseDate: clock.now(),
                    expirationDate: ExampleAppleEntitlementFixture.expirationDate(
                        clock: clock
                    ),
                    revocationDate: nil,
                    isUpgraded: false,
                    appAccountToken: nil
                )
            )
        ]
    }
}

private enum ExampleEntitlementDelay {
    static func waitIgnoringCancellation(milliseconds: Int) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + .milliseconds(milliseconds)
            ) {
                continuation.resume()
            }
        }
    }
}
