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

    private let assembler: Assembler

    init() {
        let scenario = AppConfiguration.bootstrapScenario
        let logger = OSLogBroadLogger(subsystem: AppConfiguration.loggingSubsystem)
        let cache = ExampleCacheDependencies(
            configuration: AppConfiguration.cacheFixture,
            logger: logger
        )
        let bootstrapSteps = Self.makeBootstrapSteps(
            scenario: scenario,
            cache: cache
        )
        let rootContent = AppConfiguration.rootContent(for: scenario)
        let monetizationEnvironment = ExampleMonetizationEnvironment()
        let entitlementEngine = Self.makeEntitlementEngine(
            logger: logger,
            analytics: monetizationEnvironment.analytics
        )
            ?? monetizationEnvironment.entitlementEngine
        let assembler = Self.makeAssembler(
            bootstrapSteps: bootstrapSteps,
            cacheRepository: cache.repository,
            entitlementEngine: entitlementEngine,
            monetizationServices: monetizationEnvironment.services,
            logger: logger
        )

        let composition = Self.makeComposition(
            dependencies: PlatformDependencies(resolver: assembler.resolver),
            monetizationEnvironment: monetizationEnvironment,
            rootContent: rootContent
        )

        self.assembler = assembler
        appFlowCoordinator = composition.appFlowCoordinator
        appFlowSceneViewModel = composition.appFlowSceneViewModel
        onboardingViewModel = composition.onboardingViewModel
        paywallViewModel = composition.paywallViewModel
        rootViewModel = composition.rootViewModel
        analyticsViewModel = ExampleAnalyticsViewModel(
            recorder: monetizationEnvironment.analyticsRecorder
        )
        ruSubscriptionViewModel = Self.makeRUSubscriptionViewModel()
    }

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
        rootContent: AppConfiguration.RootContent
    ) -> PlatformComposition {
        let coordinator = AppFlowCoordinator(
            configuration: AppConfiguration.appFlowConfiguration,
            progressRepository: KeyValueAppFlowProgressRepository(
                keyValueStore: dependencies.stateStore,
                keyPrefix: AppConfiguration.appFlowProgressKeyPrefix
            ),
            entitlementStatusProvider: dependencies.entitlementStatusProvider
        )

        return PlatformComposition(
            appFlowCoordinator: coordinator,
            appFlowSceneViewModel: AppFlowSceneViewModel(
                coordinator: coordinator,
                restorePurchases: dependencies.restorePurchases
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

private struct PlatformComposition {
    let appFlowCoordinator: AppFlowCoordinator
    let appFlowSceneViewModel: AppFlowSceneViewModel
    let onboardingViewModel: OnboardingViewModel
    let paywallViewModel: PaywallViewModel
    let rootViewModel: RootViewModel
}

private struct PlatformDependencies {
    let coreModule: BroadCoreModule
    let monetizationModule: BroadMonetizationModule
    let uiFlowsModule: BroadUIFlowsModule
    let runAppBootstrapUseCase: any RunAppBootstrapUseCaseProtocol
    let stateStore: any KeyValueStoreProtocol
    let entitlementStatusProvider: any EntitlementStatusProviderProtocol
    let trackingAuthorization: any TrackingAuthorizationUseCaseProtocol
    let loadPaywall: any LoadPaywallUseCaseProtocol
    let selectProduct: any SelectProductUseCaseProtocol
    let checkoutProduct: any CheckoutSelectedProductUseCaseProtocol
    let restorePurchases: any RestorePurchasesUseCaseProtocol

    init(resolver: Resolver) {
        guard
            let coreModule = resolver.resolve(BroadCoreModule.self),
            let monetizationModule = resolver.resolve(BroadMonetizationModule.self),
            let uiFlowsModule = resolver.resolve(BroadUIFlowsModule.self),
            let bootstrap = resolver.resolve(RunAppBootstrapUseCaseProtocol.self),
            let stateStore = resolver.resolve(KeyValueStoreProtocol.self),
            let entitlement = resolver.resolve(EntitlementStatusProviderProtocol.self),
            let tracking = resolver.resolve(TrackingAuthorizationUseCaseProtocol.self),
            let loadPaywall = resolver.resolve(LoadPaywallUseCaseProtocol.self),
            let selectProduct = resolver.resolve(SelectProductUseCaseProtocol.self),
            let checkout = resolver.resolve(CheckoutSelectedProductUseCaseProtocol.self),
            let restore = resolver.resolve(RestorePurchasesUseCaseProtocol.self)
        else {
            preconditionFailure("BroadApps platform assemblies are incomplete")
        }

        self.coreModule = coreModule
        self.monetizationModule = monetizationModule
        self.uiFlowsModule = uiFlowsModule
        runAppBootstrapUseCase = bootstrap
        self.stateStore = stateStore
        entitlementStatusProvider = entitlement
        trackingAuthorization = tracking
        self.loadPaywall = loadPaywall
        self.selectProduct = selectProduct
        checkoutProduct = checkout
        restorePurchases = restore
    }
}

private struct ExampleCacheDependencies {
    let repository: any CacheRepositoryProtocol
    let key: CacheKey<ExampleCachedConfiguration>
    let value: ExampleCachedConfiguration

    init(
        configuration: AppConfiguration.CacheFixture,
        logger: any BroadLoggerProtocol
    ) {
        let keyValueStore = UserDefaultsKeyValueStore(
            suiteName: configuration.suiteName,
            namespace: configuration.namespace,
            maximumDataSize: configuration.maximumDataSize
        )
        repository = VersionedJSONCacheRepository(
            keyValueStore: keyValueStore,
            maximumEncodedSize: configuration.maximumDataSize,
            logger: logger
        )
        key = CacheKey(
            name: configuration.keyName,
            schemaIdentifier: configuration.schemaIdentifier,
            version: configuration.version,
            policy: CachePolicy(timeToLive: configuration.timeToLive)
        )
        value = configuration.value
    }
}

private extension RootViewModel.Content {
    init(configuration: AppConfiguration.RootContent) {
        self.init(
            eyebrow: configuration.eyebrow,
            title: configuration.title,
            subtitle: configuration.subtitle,
            coreDescription: configuration.coreDescription,
            monetizationDescription: configuration.monetizationDescription,
            uiFlowsDescription: configuration.uiFlowsDescription,
            connectedDetail: configuration.connectedDetail,
            adaptyLinkedDetail: configuration.adaptyLinkedDetail,
            adaptyUnavailableDetail: configuration.adaptyUnavailableDetail,
            loadingTitle: configuration.loadingTitle,
            loadingMessage: configuration.loadingMessage,
            readyTitle: configuration.readyTitle,
            readyMessage: configuration.readyMessage,
            degradedTitle: configuration.degradedTitle,
            degradedMessage: configuration.degradedMessage,
            failedTitle: configuration.failedTitle,
            retryTitle: configuration.retryTitle
        )
    }
}
