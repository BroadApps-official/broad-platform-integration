import BroadMonetization

enum ExampleLiveAdaptyServicesFactory {
    static func make(
        configuration: ExampleLiveAdaptyConfiguration,
        entitlementEngine: EntitlementEngine,
        analytics: any MonetizationAnalyticsProtocol,
        pendingStore: any PendingApplePurchaseStoreProtocol,
        operationGate: MonetizationOperationGate
    ) -> BroadMonetizationServices {
        let provider = makeProvider(configuration: configuration)
        let purchase = makeRestrictedPurchase(
            entitlementEngine: entitlementEngine,
            analytics: analytics,
            pendingStore: pendingStore,
            operationGate: operationGate
        )
        let restore = makeRestrictedRestore(
            entitlementEngine: entitlementEngine,
            analytics: analytics,
            operationGate: operationGate
        )

        return BroadMonetizationServices(
            activate: provider.activate,
            loadPaywall: LoadPaywallUseCase(
                repository: provider.paywallRepository,
                analytics: analytics,
                presentationLifecycle: provider.lifecycle,
                staleLoadError: .example(
                    message: "The live Adapty paywall request was replaced.",
                    code: "example.live-adapty.paywall.stale"
                )
            ),
            selectProduct: SelectProductUseCase(),
            purchaseProduct: purchase,
            restorePurchases: restore,
            analytics: analytics,
            paywallPresentationLifecycle: provider.lifecycle,
            operationGate: operationGate
        )
    }

    private static func makeProvider(
        configuration: ExampleLiveAdaptyConfiguration
    ) -> LiveAdaptyProvider {
        let identityProvider = ExampleAnonymousAdaptyIdentityProvider()
        let messages = AdaptyMonetizationMessages(
            activationUnavailable: "The live Adapty fixture could not start.",
            paywallUnavailable: "The live Adapty paywall is unavailable.",
            productUnavailable: "This live Adapty product is unavailable.",
            purchaseFailed: "Purchases are disabled by company policy.",
            restoreFailed: "Restore is disabled by company policy."
        )
        let context = AdaptyRepositoryContext()
        let factory = AdaptyMonetizationFactory(
            configuration: configuration.platform,
            identityProvider: identityProvider,
            placementRegistry: configuration.placements,
            messages: messages,
            context: context
        )
        return LiveAdaptyProvider(
            activate: ActivateMonetizationUseCase(
                repository: AdaptyMonetizationRepository(
                    configuration: configuration.platform,
                    identityProvider: identityProvider,
                    context: context,
                    messages: messages
                )
            ),
            paywallRepository: AdaptyPaywallRepository(
                configuration: configuration.platform,
                identityProvider: identityProvider,
                placementRegistry: configuration.placements,
                context: context,
                messages: messages
            ),
            lifecycle: factory.paywallPresentationLifecycle
        )
    }

    private static func makeRestrictedPurchase(
        entitlementEngine: EntitlementEngine,
        analytics: any MonetizationAnalyticsProtocol,
        pendingStore: any PendingApplePurchaseStoreProtocol,
        operationGate: MonetizationOperationGate
    ) -> PurchaseSelectedProductUseCase {
        PurchaseSelectedProductUseCase(
            repository: RestrictedPurchaseRepository(),
            entitlementRepository: entitlementEngine,
            analytics: analytics,
            pendingStore: pendingStore,
            operationGate: operationGate,
            inProgressError: .example(
                message: "A financial operation is already in progress.",
                code: "example.live-adapty.purchase.in-progress"
            )
        )
    }

    private static func makeRestrictedRestore(
        entitlementEngine: EntitlementEngine,
        analytics: any MonetizationAnalyticsProtocol,
        operationGate: MonetizationOperationGate
    ) -> RestorePurchasesUseCase {
        RestorePurchasesUseCase(
            repository: RestrictedRestoreRepository(),
            entitlementRepository: entitlementEngine,
            analytics: analytics,
            operationGate: operationGate,
            verificationUnavailableError: .example(
                message: "Restore verification is unavailable.",
                code: "example.live-adapty.restore.unavailable"
            )
        )
    }

    static func makeUnavailable(
        entitlementEngine: EntitlementEngine,
        analytics: any MonetizationAnalyticsProtocol,
        pendingStore: any PendingApplePurchaseStoreProtocol,
        operationGate: MonetizationOperationGate
    ) -> BroadMonetizationServices {
        BroadMonetizationServices(
            activate: ActivateMonetizationUseCase(
                repository: ExampleFixtureMonetizationRepository()
            ),
            loadPaywall: LoadPaywallUseCase(
                repository: MissingLiveConfigPaywallRepository(),
                analytics: analytics,
                staleLoadError: .example(
                    message: "The live Adapty configuration is unavailable.",
                    code: "example.live-adapty.configuration-missing"
                )
            ),
            selectProduct: SelectProductUseCase(),
            purchaseProduct: makeRestrictedPurchase(
                entitlementEngine: entitlementEngine,
                analytics: analytics,
                pendingStore: pendingStore,
                operationGate: operationGate
            ),
            restorePurchases: makeRestrictedRestore(
                entitlementEngine: entitlementEngine,
                analytics: analytics,
                operationGate: operationGate
            ),
            analytics: analytics,
            paywallPresentationLifecycle: NoOpPaywallPresentationLifecycle(),
            operationGate: operationGate
        )
    }
}

private struct LiveAdaptyProvider {
    let activate: any ActivateMonetizationUseCaseProtocol
    let paywallRepository: any PaywallRepositoryProtocol
    let lifecycle: any PaywallPresentationLifecycleProtocol
}

private struct ExampleAnonymousAdaptyIdentityProvider: AdaptyIdentityProviderProtocol {
    func identity(
        for _: EntitlementSubject
    ) async -> AdaptyCustomerIdentity? {
        nil
    }
}

private struct RestrictedPurchaseRepository: PurchaseRepositoryProtocol {
    func purchase(
        _: PurchaseRequest
    ) async -> PurchaseAttemptOutcome {
        .failed(
            .example(
                message: "StoreKit purchase is disabled by company policy.",
                code: "example.company-policy.storekit-purchase-disabled"
            ),
            disposition: .definitivelyNotPurchased
        )
    }
}

private struct RestrictedRestoreRepository: RestoreRepositoryProtocol {
    func restorePurchases() async -> RestoreAttemptOutcome {
        .failed(
            .example(
                message: "StoreKit restore is disabled by company policy.",
                code: "example.company-policy.storekit-restore-disabled"
            )
        )
    }
}

private struct ExampleFixtureMonetizationRepository: MonetizationRepositoryProtocol {
    func activate() async -> MonetizationActivationOutcome {
        .activated
    }
}

private struct MissingLiveConfigPaywallRepository: PaywallRepositoryProtocol {
    func loadPaywall(
        for _: PlacementID
    ) async -> PaywallLoadOutcome {
        .unavailable(
            .example(
                message: "Import a local Adapty configuration before using this scheme.",
                code: "example.live-adapty.configuration-missing"
            )
        )
    }
}
