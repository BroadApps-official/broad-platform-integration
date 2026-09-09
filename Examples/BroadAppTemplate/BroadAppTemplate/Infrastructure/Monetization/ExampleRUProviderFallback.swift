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
        guard ["-ru-provider-unavailable", "-ru-provider-empty-products", "-ru-provider-no-matches"].contains(where: arguments.contains)
        else {
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
        if arguments.contains("-ru-provider-empty-products") || arguments.contains("-ru-provider-no-matches") {
            return RUFallbackPaywallAttempt(
                outcome: .loaded(PaywallPayload(
                    presentationID: .generated(),
                    paywallReference: .init(rawValue: "example-empty-provider"),
                    origin: .init(requestedPlacementID: placementID, resolvedPlacementID: placementID, catalogSource: .adapty),
                    products: arguments.contains("-ru-provider-no-matches") ? [Self.unmatchedProduct] : [],
                    remoteConfiguration: .init(isRUBillingEnabled: !arguments.contains("-ru-provider-response-false")),
                    remoteConfigurationProvenance: .verifiedFreshRemote,
                    fetchedAt: .now
                )),
                availability: .available
            )
        }
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

    /// Deliberately different from the local backend IDs; never sent to an SDK.
    private static var unmatchedProduct: MonetizationProduct {
        MonetizationProduct(
            presentationID: .generated(), reference: .init(rawValue: "example-unmatched-handle"),
            productID: .init(rawValue: "example.unmatched.subscription"), kind: .autoRenewableSubscription,
            price: Money(amount: 9, currencyCode: "USD"), subscriptionPeriod: .init(unit: .month, count: 1),
            catalogSource: .adapty
        )
    }
}
