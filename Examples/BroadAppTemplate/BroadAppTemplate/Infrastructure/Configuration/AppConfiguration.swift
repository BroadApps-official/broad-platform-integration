import BroadMonetization
import BroadUIFlows
import Foundation
import UIKit

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
    static let remoteFeatureScenario = ExampleRemoteFeatureScenario.current()
    static let onboardingScenario = ExampleOnboardingScenario.current()
    static let appFlowConfiguration: AppFlowConfiguration = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-app-flow-main-only") {
            return .mainOnly
        }

        if arguments.contains("-app-flow-paywall-only")
            || arguments.contains("-analytics-fixture")
            || arguments.contains("-paywall-payment-methods")
            || remoteFeatureScenario?.isRUPay == true
            || arguments.contains("-live-adapty") {
            return AppFlowConfiguration(
                onboarding: .disabled,
                initialPaywall: initialPaywallPolicy(arguments: arguments)
            )
        }

        if !onboardingScenario.isEnabled {
            return AppFlowConfiguration(
                onboarding: .disabled,
                initialPaywall: initialPaywallPolicy(arguments: arguments)
            )
        }

        return AppFlowConfiguration(
            onboarding: .enabled,
            initialPaywall: initialPaywallPolicy(arguments: arguments)
        )
    }()

    static let onboardingConfiguration = OnboardingConfiguration(
        pages: onboardingScenario.pages,
        continueTitle: "Продолжить",
        completionTitle: "Смотреть тарифы",
        progressAccessibilityLabel: "Прогресс онбординга",
        footerLinks: [
            OnboardingFooterLinkConfiguration(
                destination: .termsOfUse,
                title: "Условия"
            ),
            OnboardingFooterLinkConfiguration(
                destination: .restorePurchases,
                title: "Восстановить"
            ),
            OnboardingFooterLinkConfiguration(
                destination: .privacyPolicy,
                title: "Политика"
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
        copy: .russian,
        legalLinks: [
            BroadPaywallLegalLink(
                id: "terms",
                title: "Условия",
                url: termsOfUseURL
            ),
            BroadPaywallLegalLink(
                id: "privacy",
                title: "Политика",
                url: privacyPolicyURL
            )
        ],
        ruBilling: BroadRUBillingPresentationConfiguration(),
        specialOfferCopy: .russian
    )
    static let privacyPolicyURL = legalURL(path: "privacy")
    static let termsOfUseURL = legalURL(path: "terms")
    static let appFlowProgressKeyPrefix: String = {
        if ProcessInfo.processInfo.arguments.contains("-initial-paywall-every-cold-launch") {
            return "broad-app-template.app-flow.paywall-policy.every-cold-launch"
        }
        if ProcessInfo.processInfo.arguments.contains("-initial-paywall-disabled") {
            return "broad-app-template.app-flow.paywall-policy.disabled"
        }
        if ProcessInfo.processInfo.arguments.contains("-analytics-fixture") {
            return "broad-app-template.app-flow.analytics-fixture"
        }
        if let remoteFeatureScenario {
            return "broad-app-template.app-flow.remote-feature.\(remoteFeatureScenario.rawValue)"
        }
        if ProcessInfo.processInfo.arguments.contains("-live-adapty") {
            return "broad-app-template.app-flow.live-adapty"
        }
        if onboardingScenario != .exampleThreePages {
            return "broad-app-template.app-flow.onboarding.\(onboardingScenario.rawValue)"
        }
        guard let entitlementScenario else {
            return "broad-app-template.app-flow"
        }

        return "broad-app-template.app-flow.entitlement-fixture.\(entitlementScenario.rawValue)"
    }()

    static let loggingSubsystem: StaticString = "com.broadapps.platform.template"
    static let supportEmailRecipient = "support@example.com"
    static let supportAppStoreVersion = "1.0.0"
    #if DEBUG
        static let debugKeychainServiceNames = [
            "com.broadapps.platform.template.credentials",
            "com.broadapps.platform.template.session"
        ]
    #endif
    static let requiredServiceFailureMessage = "Обязательный сервис запуска временно недоступен."
    static let bootstrapTimeoutMessage = "Запуск занял слишком много времени. Попробуйте ещё раз."
    static let bootstrapUnknownErrorMessage = "Что-то пошло не так. Попробуйте ещё раз."
    static let staleCacheMessage = "Обновить данные по сети не удалось. Используем последнюю сохранённую конфигурацию."
    static let missingCacheMessage = "Сохранённой конфигурации нет. Сначала запустите сценарий создания кеша."
    static let invalidCacheMessage = "Сохранённую конфигурацию нельзя использовать."
    static let cacheFixture = CacheFixture(
        suiteName: "com.broadapps.platform.template.cache-fixture",
        namespace: "bootstrap-fixture",
        keyName: "configuration",
        schemaIdentifier: "broadapps.example.bootstrap-configuration",
        version: 1,
        timeToLive: 0,
        maximumDataSize: 64 * 1024,
        value: ExampleCachedConfiguration(source: "Сохранённая локальная конфигурация запуска")
    )

    @MainActor
    static var supportEmailRequest: BroadSupportEmailRequest? {
        let bundle = Bundle.main
        let installedVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        let buildNumber = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
        let supportLog = """
        [INPUT] Contact Us открыт пользователем
        [FLOW] route=contact-us; composer=checked
        [PASS] Очищенный fixture support log сформирован
        """
        let configuration = BroadSupportEmailConfiguration(
            recipient: supportEmailRecipient,
            subject: "BroadAppTemplate Support",
            greeting: .standard,
            appName: "BroadAppTemplate",
            appStoreVersion: supportAppStoreVersion,
            installedVersion: installedVersion,
            buildNumber: buildNumber,
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            systemVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            adaptyProfileID: "fixture-profile",
            backendUserID: "fixture-user",
            subscriptionStatus: "not_subscribed",
            supportLogData: Data(supportLog.utf8)
        )
        return BroadSupportEmailRequestBuilder.makeRequest(
            configuration: configuration
        )
    }

    private static func legalURL(path: String) -> URL {
        guard let url = URL(string: "https://example.com/\(path)") else {
            preconditionFailure("Example legal URL must be valid")
        }
        return url
    }

    private static func initialPaywallPolicy(
        arguments: [String]
    ) -> AppFlowInitialPaywallPolicy {
        let usesEveryColdLaunch = arguments.contains(
            "-initial-paywall-every-cold-launch"
        )
        let isDisabled = arguments.contains("-initial-paywall-disabled")
        precondition(
            !usesEveryColdLaunch || !isDisabled,
            "Use at most one initial-paywall policy launch argument"
        )

        if usesEveryColdLaunch {
            return .everyColdLaunchWhileInactive(allowsClose: true)
        }
        if isDisabled {
            return .disabled
        }
        return .onceAfterOnboarding(allowsClose: true)
    }

    static func rootContent(for scenario: ExampleBootstrapScenario) -> RootContent {
        let readyMessage: String
        let degradedMessage: String

        switch scenario {
        case .seedCache:
            readyMessage = "Локальная конфигурация сохранена. Перезапустите сценарий устаревшего кеша, чтобы проверить работу без сети."
            degradedMessage = "Основной экран доступен с ограниченными возможностями."
        case .staleCache:
            readyMessage = "Сохранённая конфигурация ещё актуальна."
            degradedMessage = staleCacheMessage
        case .ready, .degraded, .failedOnce:
            readyMessage = "Обязательные шаги завершены. Фоновые сервисы больше не блокируют экран."
            degradedMessage = "Основной экран доступен, но дополнительный сервис не ответил вовремя."
        }

        return RootContent(
            eyebrow: "BROADAPPS iOS PLATFORM",
            title: "Предсказуемый запуск приложения",
            subtitle: "Обязательные операции ограничены по времени, а дополнительные продолжаются в фоне.",
            coreDescription: "Запуск, кеш, повтор, логирование и общие контракты.",
            monetizationDescription: "Adapty, StoreKit, RU billing и проверка доступа.",
            uiFlowsDescription: "Онбординг, загрузка, пейвол и общие состояния интерфейса.",
            connectedDetail: "Подключено",
            adaptyLinkedDetail: "Adapty подключён",
            adaptyUnavailableDetail: "Adapty недоступен",
            loadingTitle: "Запускаем платформу",
            loadingMessage: "Выполняем обязательные шаги запуска…",
            readyTitle: "Платформа готова",
            readyMessage: readyMessage,
            degradedTitle: "Безопасный режим",
            degradedMessage: degradedMessage,
            failedTitle: "Не удалось завершить запуск",
            retryTitle: "Повторить"
        )
    }
}

enum ExampleRemoteFeatureScenario: String, CaseIterable, Sendable {
    case specialOfferEnabled = "special-offer-enabled"
    case specialOfferDisabled = "special-offer-disabled"
    case specialOfferPlatformCache = "special-offer-platform-cache"
    case specialOfferMainFallback = "special-offer-main-fallback"
    case specialOfferTimed = "special-offer-timed"
    case ruPayProviderEnabled = "ru-pay-provider-enabled"
    case ruPayPlatformCache = "ru-pay-platform-cache"

    var launchArgument: String {
        "-\(rawValue)"
    }

    var isSpecialOffer: Bool {
        switch self {
        case .specialOfferEnabled,
             .specialOfferDisabled,
             .specialOfferPlatformCache,
             .specialOfferMainFallback,
             .specialOfferTimed:
            true
        case .ruPayProviderEnabled, .ruPayPlatformCache:
            false
        }
    }

    var isRUPay: Bool {
        !isSpecialOffer
    }

    var specialOfferConfiguration: SpecialOfferConfiguration? {
        guard isSpecialOffer else {
            return nil
        }
        return SpecialOfferConfiguration(
            placementID: .specialOffer,
            windowDuration: self == .specialOfferTimed ? 180 : nil
        )
    }

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ExampleRemoteFeatureScenario? {
        let matches = allCases.filter { arguments.contains($0.launchArgument) }
        precondition(
            matches.count <= 1,
            "Use at most one remote-feature fixture launch argument"
        )
        return matches.first
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
