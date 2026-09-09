import BroadCore
import BroadMonetization

/// Local fixture only. Production uses ruFactory.makePaywallLoader or
/// adaptyFactory.makeServicesWithRUFallback with the application's backend.
enum ExampleRUProviderFallback {
    static func makeLoader(
        arguments: [String], analytics: any MonetizationAnalyticsProtocol
    ) -> any LoadPaywallUseCaseProtocol {
        let provider = ExamplePaywallRepository(arguments: arguments)
        let error = AppError.example(
            message: "Предыдущий запрос пейвола отменён новым. Попробуйте ещё раз.",
            code: "example.paywall.stale"
        )
        guard arguments.contains("-ru-provider-unavailable") else {
            return LoadPaywallUseCase(repository: provider, analytics: analytics, staleLoadError: error)
        }
        let region = ExampleRURegionalScenario.current(arguments: arguments)
        return LoadPaywallWithRUFallbackUseCase(
            provider: provider,
            catalog: ExampleRUCatalogRepository(),
            storefront: ExampleRUStorefrontRepository(scenario: region),
            gate: RUBillingGate(
                isFeatureEnabled: true,
                deviceContextProvider: ExampleRUBillingDeviceContextProvider(scenario: region)
            ),
            analytics: analytics,
            staleLoadError: error
        )
    }
}

extension ExamplePaywallRepository {
    func loadRUFallbackAttempt(for placementID: PlacementID) async -> RUFallbackPaywallAttempt {
        guard arguments.contains("-ru-provider-unavailable") else {
            return await RUFallbackPaywallAttempt(outcome: loadPaywall(for: placementID), availability: .available)
        }
        let configuration: RemotePaywallConfiguration? = arguments.contains("-ru-provider-response-false")
            ? RemotePaywallConfiguration(isRUBillingEnabled: false) : nil
        return RUFallbackPaywallAttempt(
            outcome: .unavailable(.example(
                message: "В этом примере Adapty недоступен. Повторите загрузку.",
                code: "example.adapty.provider-unavailable"
            )),
            availability: .unavailable(receivedConfiguration: configuration)
        )
    }
}
