import BroadCore
import BroadMonetization
import BroadUIFlows
import Foundation
import Swinject

@MainActor
final class AppCompositionRoot {
    let appFlowCoordinator: AppFlowCoordinator
    let appFlowSceneViewModel: AppFlowSceneViewModel
    let onboardingViewModel: OnboardingViewModel
    let paywallViewModel: PaywallViewModel
    let rootViewModel: RootViewModel
    let analyticsViewModel: ExampleAnalyticsViewModel
    let ruSubscriptionViewModel: BroadRUSubscriptionManagementViewModel
    let catalogSpecialOfferViewModel: ExampleSpecialOfferFixtureViewModel
    let tokenPaywallViewModel: BroadTokenPaywallViewModel
    let tokenBalanceViewModel: ExampleTokenBalanceViewModel
    let supportEmailRequest: () -> BroadSupportEmailRequest?
    #if DEBUG
        let debugSettingsViewModel: ExampleDebugSettingsViewModel
    #endif

    private let assembler: Assembler

    init() {
        let runtime = Self.makeRuntime()
        let supportLogRecorder = runtime.supportLogRecorder
        let tokenComposition = Self.makeTokenComposition(
            environment: runtime.monetizationEnvironment,
            logger: runtime.logger
        )
        assembler = runtime.assembler
        appFlowCoordinator = runtime.composition.appFlowCoordinator
        appFlowSceneViewModel = runtime.composition.appFlowSceneViewModel
        onboardingViewModel = runtime.composition.onboardingViewModel
        paywallViewModel = runtime.composition.paywallViewModel
        rootViewModel = runtime.composition.rootViewModel
        analyticsViewModel = ExampleAnalyticsViewModel(
            recorder: runtime.monetizationEnvironment.analyticsRecorder
        )
        ruSubscriptionViewModel = Self.makeRUSubscriptionViewModel()
        catalogSpecialOfferViewModel = Self.makeCatalogSpecialOfferViewModel(
            logger: runtime.logger,
            analyticsRecorder: runtime.monetizationEnvironment.analyticsRecorder
        )
        tokenPaywallViewModel = tokenComposition.paywallViewModel
        tokenBalanceViewModel = tokenComposition.balanceViewModel
        supportEmailRequest = {
            AppConfiguration.supportEmailRequest(
                supportLogData: supportLogRecorder.makeSupportLogData()
            )
        }
        #if DEBUG
            debugSettingsViewModel = Self.makeDebugSettingsViewModel(
                progressRepository: runtime.composition.progressRepository,
                cacheRepository: runtime.cache.repository,
                cacheKey: runtime.cache.key,
                analyticsRecorder: runtime.monetizationEnvironment.analyticsRecorder,
                ruBillingOverrideStore: runtime.monetizationEnvironment
                    .debugRUBillingOverrideStore
            )
        #endif
    }
}

private extension AppCompositionRoot {
    static func makeRuntime() -> CompositionRuntime {
        let scenario = AppConfiguration.bootstrapScenario
        let supportLogRecorder = BroadSupportLogRecorder()
        let logger = CompositeBroadLogger(
            loggers: [
                OSLogBroadLogger(subsystem: AppConfiguration.loggingSubsystem),
                supportLogRecorder
            ]
        )
        let cache = ExampleCacheDependencies(
            configuration: AppConfiguration.cacheFixture,
            logger: logger
        )
        let monetizationEnvironment = ExampleMonetizationEnvironment(
            logger: logger
        )
        let entitlementEngine = makeEntitlementEngine(
            logger: logger,
            analytics: monetizationEnvironment.analytics
        ) ?? monetizationEnvironment.entitlementEngine
        let assembler = makeAssembler(
            bootstrapSteps: makeBootstrapSteps(scenario: scenario, cache: cache),
            cacheRepository: cache.repository,
            entitlementEngine: entitlementEngine,
            monetizationServices: monetizationEnvironment.services,
            logger: logger
        )
        let specialOfferViewModel = makeSpecialOfferFixtureViewModel(
            environment: monetizationEnvironment,
            logger: logger
        )
        let composition = makeComposition(
            dependencies: PlatformDependencies(resolver: assembler.resolver),
            monetizationEnvironment: monetizationEnvironment,
            specialOfferViewModel: specialOfferViewModel,
            rootContent: AppConfiguration.rootContent(for: scenario),
            logger: logger
        )
        return CompositionRuntime(
            assembler: assembler,
            composition: composition,
            monetizationEnvironment: monetizationEnvironment,
            specialOfferViewModel: specialOfferViewModel,
            supportLogRecorder: supportLogRecorder,
            logger: logger,
            cache: cache
        )
    }

    private static func makeCatalogSpecialOfferViewModel(
        logger: any BroadLoggerProtocol,
        analyticsRecorder: ExampleRecordingMonetizationAnalytics
    ) -> ExampleSpecialOfferFixtureViewModel {
        let arguments = ["BroadAppTemplate", "-special-offer-enabled"]
        let environment = ExampleMonetizationEnvironment(
            arguments: arguments,
            logger: logger,
            analyticsRecorder: analyticsRecorder
        )
        let scenario = ExampleRemoteFeatureScenario.specialOfferEnabled
        guard let configuration = scenario.specialOfferConfiguration,
              let resolver = environment.resolveSpecialOffer
        else {
            preconditionFailure("Special Offer catalog fixture is incomplete")
        }

        return ExampleSpecialOfferFixtureViewModel(
            scenario: scenario,
            resolver: resolver,
            configuration: configuration,
            paywallDependencies: PaywallViewModelDependencies(
                loadPaywall: environment.services.loadPaywall,
                selectProduct: environment.services.selectProduct,
                checkoutProduct: environment.services.checkoutProduct,
                restorePurchases: environment.services.restorePurchases,
                resolveCheckoutMethods: environment.resolveCheckoutMethods,
                trackEvent: environment.trackPaywallEvent,
                presentationLifecycle: environment.services.paywallPresentationLifecycle,
                operationGate: environment.services.operationGate
            ),
            logger: logger
        )
    }

    private static func makeSpecialOfferFixtureViewModel(
        environment: ExampleMonetizationEnvironment,
        logger: any BroadLoggerProtocol
    ) -> ExampleSpecialOfferFixtureViewModel? {
        guard let scenario = AppConfiguration.remoteFeatureScenario,
              let configuration = scenario.specialOfferConfiguration,
              let resolver = environment.resolveSpecialOffer
        else {
            return nil
        }
        return ExampleSpecialOfferFixtureViewModel(
            scenario: scenario,
            resolver: resolver,
            configuration: configuration,
            paywallDependencies: PaywallViewModelDependencies(
                loadPaywall: environment.services.loadPaywall,
                selectProduct: environment.services.selectProduct,
                checkoutProduct: environment.services.checkoutProduct,
                restorePurchases: environment.services.restorePurchases,
                resolveCheckoutMethods: environment.resolveCheckoutMethods,
                trackEvent: environment.trackPaywallEvent,
                presentationLifecycle: environment.services.paywallPresentationLifecycle,
                operationGate: environment.services.operationGate
            ),
            logger: logger
        )
    }

    #if DEBUG
        private static func makeDebugSettingsViewModel(
            progressRepository: any AppFlowProgressRepositoryProtocol,
            cacheRepository: any CacheRepositoryProtocol,
            cacheKey: CacheKey<ExampleCachedConfiguration>,
            analyticsRecorder: ExampleRecordingMonetizationAnalytics,
            ruBillingOverrideStore: RUBillingDebugOverrideStore
        )
            -> ExampleDebugSettingsViewModel {
            let cleaner = DebugKeychainCleaner(
                scopes: AppConfiguration.debugKeychainServiceNames.map {
                    DebugKeychainScope(service: $0)
                },
                failureError: .example(
                    message: "Не удалось очистить Keychain приложения.",
                    code: "example.debug.keychain-cleanup-failed"
                )
            )
            return ExampleDebugSettingsViewModel(
                keychainCleaner: cleaner,
                progressRepository: progressRepository,
                contentCacheCleaner: ExampleDebugContentCacheCleaner(
                    repository: cacheRepository,
                    key: cacheKey
                ),
                analyticsRecorder: analyticsRecorder,
                ruBillingOverrideStore: ruBillingOverrideStore
            )
        }
    #endif

    private static func makeRUSubscriptionViewModel()
        -> BroadRUSubscriptionManagementViewModel {
        let state = ExampleRUSubscriptionState(
            isCancelled: ProcessInfo.processInfo.arguments.contains(
                "-ru-subscription-cancelled"
            )
        )
        return BroadRUSubscriptionManagementViewModel(
            dependencies: BroadRUSubscriptionDependencies(
                loadStatus: ExampleLoadRUSubscriptionStatusUseCase(state: state),
                cancelSubscription: ExampleCancelRUSubscriptionUseCase(
                    state: state
                )
            )
        )
    }

    private static func makeBootstrapSteps(
        scenario: ExampleBootstrapScenario,
        cache: ExampleCacheDependencies
    ) -> [BootstrapStep] {
        scenario.makeSteps(
            requiredServiceFailureMessage: AppConfiguration.requiredServiceFailureMessage,
            cacheRepository: cache.repository,
            cacheKey: cache.key,
            cacheValue: cache.value,
            staleCacheMessage: AppConfiguration.staleCacheMessage,
            missingCacheMessage: AppConfiguration.missingCacheMessage,
            invalidCacheMessage: AppConfiguration.invalidCacheMessage
        )
    }

    private static func makeEntitlementEngine(
        logger: any BroadLoggerProtocol,
        analytics: any MonetizationAnalyticsProtocol
    ) -> EntitlementEngine? {
        AppConfiguration.entitlementScenario.map {
            ExampleEntitlementDependencies(
                scenario: $0,
                logger: logger,
                analytics: analytics
            ).engine
        }
    }

    private static func makeAssembler(
        bootstrapSteps: [BootstrapStep],
        cacheRepository: any CacheRepositoryProtocol,
        entitlementEngine: EntitlementEngine,
        monetizationServices: BroadMonetizationServices,
        logger: any BroadLoggerProtocol
    ) -> Assembler {
        Assembler([
            BroadCoreAssembly(
                bootstrapSteps: bootstrapSteps,
                bootstrapErrorMessages: BootstrapErrorMessages(
                    timeout: AppConfiguration.bootstrapTimeoutMessage,
                    unknown: AppConfiguration.bootstrapUnknownErrorMessage
                ),
                cacheRepository: cacheRepository,
                logger: logger
            ),
            BroadMonetizationAssembly(
                entitlementEngine: entitlementEngine,
                services: monetizationServices
            ),
            BroadUIFlowsAssembly()
        ])
    }

    private static func makeComposition(
        dependencies: PlatformDependencies,
        monetizationEnvironment: ExampleMonetizationEnvironment,
        specialOfferViewModel: ExampleSpecialOfferFixtureViewModel?,
        rootContent: AppConfiguration.RootContent,
        logger: any BroadLoggerProtocol
    ) -> PlatformComposition {
        let progressRepository = KeyValueAppFlowProgressRepository(
            keyValueStore: dependencies.stateStore,
            keyPrefix: AppConfiguration.appFlowProgressKeyPrefix
        )
        let coordinator = AppFlowCoordinator(
            configuration: AppConfiguration.appFlowConfiguration,
            progressRepository: progressRepository,
            entitlementStatusProvider: dependencies.entitlementStatusProvider
        )

        return PlatformComposition(
            progressRepository: progressRepository,
            appFlowCoordinator: coordinator,
            appFlowSceneViewModel: AppFlowSceneViewModel(
                coordinator: coordinator,
                restorePurchases: dependencies.restorePurchases,
                specialOfferViewModel: specialOfferViewModel,
                logger: logger
            ),
            onboardingViewModel: OnboardingViewModel(
                configuration: AppConfiguration.onboardingConfiguration,
                requestTrackingAuthorizationUseCase: dependencies.trackingAuthorization
            ),
            paywallViewModel: PaywallViewModel(
                configuration: AppConfiguration.paywallConfiguration,
                dependencies: PaywallViewModelDependencies(
                    loadPaywall: dependencies.loadPaywall,
                    selectProduct: dependencies.selectProduct,
                    checkoutProduct: dependencies.checkoutProduct,
                    restorePurchases: dependencies.restorePurchases,
                    resolveCheckoutMethods: monetizationEnvironment.resolveCheckoutMethods,
                    trackEvent: monetizationEnvironment.trackPaywallEvent,
                    presentationLifecycle: monetizationEnvironment.services
                        .paywallPresentationLifecycle,
                    operationGate: monetizationEnvironment.services.operationGate
                )
            ),
            rootViewModel: RootViewModel(
                content: RootViewModel.Content(configuration: rootContent),
                coreModule: dependencies.coreModule,
                monetizationModule: dependencies.monetizationModule,
                uiFlowsModule: dependencies.uiFlowsModule,
                runAppBootstrapUseCase: dependencies.runAppBootstrapUseCase,
                appFlowCoordinator: coordinator
            )
        )
    }
}
