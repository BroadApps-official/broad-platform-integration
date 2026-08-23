import BroadCore
import BroadMonetization
import Foundation

struct ExampleMonetizationEnvironment {
    let entitlementEngine: EntitlementEngine
    let services: BroadMonetizationServices
    let resolveCheckoutMethods: any ResolveCheckoutMethodsUseCaseProtocol
    let trackPaywallEvent: any TrackPaywallEventUseCaseProtocol
    let analytics: any MonetizationAnalyticsProtocol
    let analyticsRecorder: ExampleRecordingMonetizationAnalytics
    let resolveSpecialOffer: (any ResolveSpecialOfferUseCaseProtocol)?

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        logger: any BroadLoggerProtocol = NoOpBroadLogger(),
        analyticsRecorder sharedAnalyticsRecorder: ExampleRecordingMonetizationAnalytics? = nil
    ) {
        let accessState = ExamplePremiumAccessState()
        let analyticsRecorder = sharedAnalyticsRecorder
            ?? ExampleRecordingMonetizationAnalytics(logger: logger)
        let analytics = ExampleMonetizationAnalyticsAssembly.make(
            recorder: analyticsRecorder
        )
        let pendingApplePurchaseStore = InMemoryPendingApplePurchaseStore()
        let entitlementEngine = Self.makeEntitlementEngine(
            accessState: accessState,
            analytics: analytics
        )
        let operationGate = MonetizationOperationGate()
        let remoteFeatureScenario = ExampleRemoteFeatureScenario.current(
            arguments: arguments
        )
        let services = Self.makeSelectedServices(
            arguments: arguments,
            accessState: accessState,
            analytics: analytics,
            pendingStore: pendingApplePurchaseStore,
            entitlementEngine: entitlementEngine,
            operationGate: operationGate
        )

        self.entitlementEngine = entitlementEngine
        self.analytics = analytics
        self.analyticsRecorder = analyticsRecorder
        self.services = services
        resolveCheckoutMethods = Self.makeCheckoutMethodsUseCase(
            arguments: arguments,
            scenario: remoteFeatureScenario
        )
        trackPaywallEvent = services.trackPaywallEvent
        resolveSpecialOffer = Self.makeSpecialOfferResolver(
            scenario: remoteFeatureScenario,
            services: services
        )
    }

    private static func makeSelectedServices(
        arguments: [String],
        accessState: ExamplePremiumAccessState,
        analytics: any MonetizationAnalyticsProtocol,
        pendingStore: InMemoryPendingApplePurchaseStore,
        entitlementEngine: EntitlementEngine,
        operationGate: MonetizationOperationGate
    ) -> BroadMonetizationServices {
        if let configuration = ExampleLiveAdaptyConfiguration.load(arguments: arguments) {
            return ExampleLiveAdaptyServicesFactory.make(
                configuration: configuration,
                entitlementEngine: entitlementEngine,
                analytics: analytics,
                pendingStore: pendingStore,
                operationGate: operationGate
            )
        }
        if arguments.contains("-live-adapty") {
            return ExampleLiveAdaptyServicesFactory.makeUnavailable(
                entitlementEngine: entitlementEngine,
                analytics: analytics,
                pendingStore: pendingStore,
                operationGate: operationGate
            )
        }
        return makeServices(
            arguments: arguments,
            accessState: accessState,
            analytics: analytics,
            pendingApplePurchaseStore: pendingStore,
            entitlementEngine: entitlementEngine,
            operationGate: operationGate
        )
    }

    private static func makeCheckoutMethodsUseCase(
        arguments: [String],
        scenario: ExampleRemoteFeatureScenario?
    ) -> any ResolveCheckoutMethodsUseCaseProtocol {
        if scenario?.isRUPay == true {
            return makeRUPayFixtureMethodsUseCase()
        }
        if arguments.contains("-paywall-payment-methods") {
            return ExampleCheckoutMethodsUseCase()
        }
        return DisabledRUBillingCheckoutMethodsUseCase()
    }

    private static func makeSpecialOfferResolver(
        scenario: ExampleRemoteFeatureScenario?,
        services: BroadMonetizationServices
    ) -> (any ResolveSpecialOfferUseCaseProtocol)? {
        guard let scenario, scenario.isSpecialOffer else {
            return nil
        }
        return ResolveSpecialOfferUseCase(
            loadPaywallUseCase: services.loadPaywall,
            stateRepository: ExampleSpecialOfferStateRepository(),
            presentationLifecycle: services.paywallPresentationLifecycle,
            clock: scenario == .specialOfferTimed ? fixtureTrustedClock : .untrusted
        )
    }

    private static var fixtureTrustedClock: SpecialOfferClock {
        SpecialOfferClock {
            // Fixed fixture server time: this is intentionally not device
            // `Date()` and never leaves the example target.
            .trusted(Date(timeIntervalSince1970: 1_800_000_000))
        }
    }

    private static func makeServices(
        arguments: [String],
        accessState: ExamplePremiumAccessState,
        analytics: any MonetizationAnalyticsProtocol,
        pendingApplePurchaseStore: InMemoryPendingApplePurchaseStore,
        entitlementEngine: EntitlementEngine,
        operationGate: MonetizationOperationGate
    ) -> BroadMonetizationServices {
        let loadPaywall = LoadPaywallUseCase(
            repository: ExamplePaywallRepository(arguments: arguments),
            analytics: analytics,
            staleLoadError: .example(
                message: "Предыдущий запрос пейвола отменён новым. Попробуйте ещё раз.",
                code: "example.paywall.stale"
            )
        )
        return BroadMonetizationServices(
            activate: ActivateMonetizationUseCase(
                repository: ExampleMonetizationRepository()
            ),
            loadPaywall: loadPaywall,
            selectProduct: SelectProductUseCase(),
            purchaseProduct: PurchaseSelectedProductUseCase(
                repository: ExamplePurchaseRepository(
                    accessState: accessState,
                    arguments: arguments
                ),
                entitlementRepository: entitlementEngine,
                analytics: analytics,
                pendingStore: pendingApplePurchaseStore,
                operationGate: operationGate,
                inProgressError: .example(
                    message: "Покупка уже выполняется.",
                    code: "example.purchase.in-progress"
                )
            ),
            restorePurchases: RestorePurchasesUseCase(
                repository: ExampleRestoreRepository(
                    accessState: accessState,
                    arguments: arguments
                ),
                entitlementRepository: entitlementEngine,
                analytics: analytics,
                operationGate: operationGate,
                verificationUnavailableError: .example(
                    message: "Не удалось проверить покупку. Попробуйте ещё раз.",
                    code: "example.restore.verification-unavailable"
                )
            ),
            analytics: analytics,
            paywallPresentationLifecycle: NoOpPaywallPresentationLifecycle()
        )
    }

    private static func makeRUPayFixtureMethodsUseCase()
        -> any ResolveCheckoutMethodsUseCaseProtocol {
        ResolveCheckoutMethodsUseCase(
            storefrontRepository: ExampleRUStorefrontRepository(),
            catalogRepository: ExampleRUCatalogRepository(),
            isFeatureEnabled: true,
            deviceContextProvider: ExampleRussianDeviceContextProvider()
        )
    }

    private static func makeEntitlementEngine(
        accessState: ExamplePremiumAccessState,
        analytics: any MonetizationAnalyticsProtocol
    ) -> EntitlementEngine {
        let subject = EntitlementSubject.anonymous
        let registration = EntitlementSourceRegistration(
            source: .apple,
            subject: subject,
            freshnessPolicy: EntitlementFreshnessPolicy(
                timeToLive: 30,
                offlineActiveGrace: 0
            ),
            repository: ExampleEntitlementSourceRepository(
                accessState: accessState
            )
        )

        return EntitlementEngine(
            registrations: [registration],
            subject: subject,
            cache: ExampleEntitlementCache(),
            timeoutPolicy: .seconds(1),
            analytics: analytics
        )
    }
}

actor ExamplePremiumAccessState {
    private var isActive = false

    func activate() {
        isActive = true
    }

    func currentValue() -> Bool {
        isActive
    }
}

private struct ExampleEntitlementSourceRepository: EntitlementSourceRepositoryProtocol {
    let accessState: ExamplePremiumAccessState

    func resolveEntitlement(
        for subject: EntitlementSubject
    ) async -> EntitlementSourceResolution {
        guard subject == .anonymous else {
            return .unresolved
        }

        return await accessState.currentValue() ? .active(.unspecified) : .inactive
    }
}

private actor ExampleEntitlementCache: EntitlementCacheProtocol {
    private var assertions: [EntitlementCacheScope: EntitlementSourceAssertion] = [:]

    func read(
        for scope: EntitlementCacheScope
    ) -> EntitlementSourceAssertion? {
        assertions[scope]
    }

    func write(
        _ assertion: EntitlementSourceAssertion,
        for scope: EntitlementCacheScope
    ) {
        assertions[scope] = assertion
    }
}

private struct ExampleMonetizationRepository: MonetizationRepositoryProtocol {
    func activate() async -> MonetizationActivationOutcome {
        .activated
    }
}

private struct ExamplePurchaseRepository: PurchaseRepositoryProtocol {
    let accessState: ExamplePremiumAccessState
    let arguments: [String]

    func purchase(
        _ request: PurchaseRequest
    ) async -> PurchaseAttemptOutcome {
        guard request.checkoutMethod == .apple else {
            return .failed(
                .example(
                    message: "RU billing отключён, пока приложение не передаст конфигурацию.",
                    code: "example.purchase.ru-disabled"
                ),
                disposition: .definitivelyNotPurchased
            )
        }
        if arguments.contains("-purchase-cancelled") {
            return .cancelled
        }
        if arguments.contains("-purchase-pending") {
            return .pending
        }
        if arguments.contains("-purchase-failure") {
            return .failed(
                .example(
                    message: "Не удалось выполнить тестовую покупку. Попробуйте ещё раз.",
                    code: "example.purchase.failed"
                ),
                disposition: .definitivelyNotPurchased
            )
        }

        await accessState.activate()
        return .completed(
            PurchaseConfirmation(
                productID: request.selection.product.productID,
                checkoutMethod: request.checkoutMethod,
                confirmedAt: Date()
            )
        )
    }
}
