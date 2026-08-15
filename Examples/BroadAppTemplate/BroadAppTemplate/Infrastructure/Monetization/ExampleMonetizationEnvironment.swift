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

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let accessState = ExamplePremiumAccessState()
        let analyticsRecorder = ExampleRecordingMonetizationAnalytics()
        let analytics = ExampleMonetizationAnalyticsAssembly.make(
            recorder: analyticsRecorder
        )
        let pendingApplePurchaseStore = InMemoryPendingApplePurchaseStore()
        let entitlementEngine = Self.makeEntitlementEngine(
            accessState: accessState,
            analytics: analytics
        )
        let operationGate = MonetizationOperationGate()
        let liveAdaptyConfiguration = ExampleLiveAdaptyConfiguration.load(
            arguments: arguments
        )

        self.entitlementEngine = entitlementEngine
        self.analytics = analytics
        self.analyticsRecorder = analyticsRecorder
        if let liveAdaptyConfiguration {
            services = ExampleLiveAdaptyServicesFactory.make(
                configuration: liveAdaptyConfiguration,
                entitlementEngine: entitlementEngine,
                analytics: analytics,
                pendingStore: pendingApplePurchaseStore,
                operationGate: operationGate
            )
        } else if arguments.contains("-live-adapty") {
            services = ExampleLiveAdaptyServicesFactory.makeUnavailable(
                entitlementEngine: entitlementEngine,
                analytics: analytics,
                pendingStore: pendingApplePurchaseStore,
                operationGate: operationGate
            )
        } else {
            services = Self.makeServices(
                arguments: arguments,
                accessState: accessState,
                analytics: analytics,
                pendingApplePurchaseStore: pendingApplePurchaseStore,
                entitlementEngine: entitlementEngine,
                operationGate: operationGate
            )
        }
        if arguments.contains("-paywall-payment-methods") {
            resolveCheckoutMethods = ExampleCheckoutMethodsUseCase()
        } else {
            resolveCheckoutMethods = DisabledRUBillingCheckoutMethodsUseCase()
        }
        trackPaywallEvent = services.trackPaywallEvent
    }

    private static func makeServices(
        arguments: [String],
        accessState: ExamplePremiumAccessState,
        analytics: any MonetizationAnalyticsProtocol,
        pendingApplePurchaseStore: InMemoryPendingApplePurchaseStore,
        entitlementEngine: EntitlementEngine,
        operationGate: MonetizationOperationGate
    ) -> BroadMonetizationServices {
        BroadMonetizationServices(
            activate: ActivateMonetizationUseCase(
                repository: ExampleMonetizationRepository()
            ),
            loadPaywall: LoadPaywallUseCase(
                repository: ExamplePaywallRepository(arguments: arguments),
                analytics: analytics,
                staleLoadError: .example(
                    message: "Предыдущий запрос пейвола отменён новым. Попробуйте ещё раз.",
                    code: "example.paywall.stale"
                )
            ),
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

private struct ExamplePaywallRepository: PaywallRepositoryProtocol {
    let arguments: [String]

    func loadPaywall(
        for placementID: PlacementID
    ) async -> PaywallLoadOutcome {
        if arguments.contains("-paywall-failure") {
            return .unavailable(
                .example(
                    message: "Тарифы временно недоступны.",
                    code: "example.paywall.unavailable"
                )
            )
        }

        let productCount = Self.productCount(arguments: arguments)
        let isHardPaywall = arguments.contains("-paywall-hard")
        return .loaded(
            PaywallPayload(
                presentationID: .generated(),
                paywallReference: PaywallReference(
                    rawValue: "example-\(placementID.rawValue)-paywall"
                ),
                variationID: PaywallVariationID(rawValue: "example-local-fixture"),
                origin: PaywallOrigin(
                    requestedPlacementID: placementID,
                    resolvedPlacementID: placementID,
                    catalogSource: .adapty
                ),
                products: Self.products(
                    count: productCount,
                    usesRUBillingFixture: arguments.contains(
                        "-paywall-payment-methods"
                    )
                ),
                remoteConfiguration: RemotePaywallConfiguration(
                    isRUBillingEnabled: arguments.contains("-paywall-payment-methods"),
                    accessPolicy: isHardPaywall ? .hard : .soft,
                    closeDelay: isHardPaywall ? nil : 0,
                    uiVariantID: PaywallUIVariantID(rawValue: "example-adaptive")
                ),
                remoteConfigurationProvenance: .verifiedFreshRemote,
                fetchedAt: Date()
            )
        )
    }

    private static func productCount(arguments: [String]) -> Int {
        if arguments.contains("-paywall-empty") {
            return 0
        }
        if arguments.contains("-paywall-one-product") {
            return 1
        }
        if arguments.contains("-paywall-two-products") {
            return 2
        }
        if arguments.contains("-paywall-many-products") {
            return 12
        }
        return 4
    }

    private static func products(
        count: Int,
        usesRUBillingFixture: Bool
    ) -> [MonetizationProduct] {
        let fixtures = ProductFixture.all
        return (0 ..< count).map { index in
            let fixture = fixtures[index % fixtures.count]
            return MonetizationProduct(
                presentationID: .generated(),
                reference: ProductReference(
                    rawValue: "example-product-reference-\(index)-\(UUID().uuidString)"
                ),
                productID: ProductID(rawValue: fixture.productID),
                kind: fixture.kind,
                title: fixture.title,
                subtitle: fixture.subtitle,
                price: Money(
                    amount: fixture.amount,
                    currencyCode: usesRUBillingFixture ? "RUB" : "USD"
                ),
                displayPrice: usesRUBillingFixture
                    ? fixture.rubleDisplayPrice
                    : fixture.displayPrice,
                subscriptionPeriod: fixture.period,
                catalogSource: .adapty
            )
        }
    }
}

private extension ExamplePaywallRepository {
    struct ProductFixture {
        let productID: String
        let kind: MonetizationProductKind
        let title: String
        let subtitle: String?
        let amount: Decimal
        let displayPrice: String
        let rubleDisplayPrice: String
        let period: SubscriptionPeriod

        static let all = [
            ProductFixture(
                productID: "example.premium.weekly",
                kind: .autoRenewableSubscription,
                title: "Недельная подписка",
                subtitle: "Гибкий доступ",
                amount: 3.99,
                displayPrice: "$3.99",
                rubleDisplayPrice: "299 ₽",
                period: .week()
            ),
            ProductFixture(
                productID: "example.premium.monthly",
                kind: .autoRenewableSubscription,
                title: "Месячная подписка",
                subtitle: "Самый популярный тариф",
                amount: 8.99,
                displayPrice: "$8.99",
                rubleDisplayPrice: "699 ₽",
                period: .month()
            ),
            ProductFixture(
                productID: "example.premium.yearly",
                kind: .autoRenewableSubscription,
                title: "Годовая подписка с намеренно длинным локализованным названием",
                subtitle: "Один платёж за двенадцать месяцев",
                amount: 49.99,
                displayPrice: "$49.99",
                rubleDisplayPrice: "3 990 ₽",
                period: .year()
            ),
            ProductFixture(
                productID: "example.premium.unknown",
                kind: .unknown,
                title: "Доступ, заданный провайдером",
                subtitle: "Продукт без известного периода остаётся видимым",
                amount: 12.49,
                displayPrice: "$12.49",
                rubleDisplayPrice: "999 ₽",
                period: .unknown
            )
        ]
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
