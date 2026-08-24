import BroadMonetization

/// UI-only fixture for the payment-method sheet. It deliberately does not make
/// RU checkout operational: choosing an RU method still reaches the disabled
/// adapter and returns the platform's safe not-configured error.
struct ExampleCheckoutMethodsUseCase: ResolveCheckoutMethodsUseCaseProtocol {
    func callAsFunction(
        for _: MonetizationProduct,
        remoteConfiguration _: RemotePaywallConfiguration
    ) async -> CheckoutMethodsResolution {
        CheckoutMethodsResolution(
            methods: [.apple, .sbp, .card],
            storefront: Storefront(
                identifier: "example-ru-storefront",
                countryCode: "RU"
            ),
            ruBillingAvailability: .available
        )
    }
}
