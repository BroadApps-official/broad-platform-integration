import BroadCore
import BroadMonetization
import BroadUIFlows

extension AppCompositionRoot {
    static func makeTokenComposition(
        environment: ExampleMonetizationEnvironment,
        logger: any BroadLoggerProtocol
    ) -> ExampleTokenComposition {
        let balanceViewModel = ExampleTokenBalanceViewModel(logger: logger)
        let transactionLedger = ExampleTokenTransactionLedger()
        let fulfillmentRepository = ExampleTokenFulfillmentRepository()
        let purchaseManager = makeTokenPurchaseManager(
            environment: environment,
            transactionLedger: transactionLedger,
            fulfillmentRepository: fulfillmentRepository
        )
        let loadPaywall = LoadPaywallUseCase(
            repository: ExampleTokenPaywallRepository(),
            analytics: environment.analytics,
            staleLoadError: .example(
                message: "Token catalog был заменён более новым запросом.",
                code: "example.tokens.stale-load"
            )
        )
        let paywallViewModel = BroadTokenPaywallViewModel(
            configuration: BroadTokenPaywallConfiguration(copy: .russian),
            dependencies: BroadTokenPaywallViewModelDependencies(
                loadPaywall: loadPaywall,
                selectProduct: SelectProductUseCase(),
                purchaseManager: purchaseManager,
                recoverTokenAccount: fulfillmentRepository,
                onBalanceConfirmed: { [weak balanceViewModel] snapshot in
                    balanceViewModel?.applyConfirmed(snapshot)
                }
            )
        )
        return ExampleTokenComposition(
            paywallViewModel: paywallViewModel,
            balanceViewModel: balanceViewModel
        )
    }

    private static func makeTokenPurchaseManager(
        environment: ExampleMonetizationEnvironment,
        transactionLedger: ExampleTokenTransactionLedger,
        fulfillmentRepository: ExampleTokenFulfillmentRepository
    ) -> TokenPurchaseManager {
        TokenPurchaseManager(
            purchaseRepository: ExampleTokenPurchaseRepository(
                ledger: transactionLedger
            ),
            evidenceProvider: ExampleTokenTransactionEvidenceProvider(
                ledger: transactionLedger
            ),
            fulfillmentRepository: fulfillmentRepository,
            pendingStore: InMemoryPendingTokenPurchaseStore(
                applicationIdentifier: "dev.broadapps.template.tokens"
            ),
            analytics: environment.analytics,
            operationGate: environment.services.operationGate,
            inProgressError: .example(
                message: "Другая финансовая fixture-операция уже выполняется.",
                code: "example.tokens.in-progress"
            ),
            unavailableError: .example(
                message: "Token transaction сохранена и ждёт безопасной сверки.",
                code: "example.tokens.fulfillment-unavailable"
            ),
            unsupportedProductError: .example(
                message: "Выбранный продукт не является consumable token package.",
                code: "example.tokens.unsupported-product"
            )
        )
    }
}

struct ExampleTokenComposition {
    let paywallViewModel: BroadTokenPaywallViewModel
    let balanceViewModel: ExampleTokenBalanceViewModel
}
