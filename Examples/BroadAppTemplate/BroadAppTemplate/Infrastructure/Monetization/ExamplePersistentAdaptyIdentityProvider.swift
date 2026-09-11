import BroadCore
import BroadMonetization
import Foundation

/// Persists the anonymous Adapty customer ID; it does not authenticate a backend account.
struct ExamplePersistentAdaptyIdentityProvider: AdaptyIdentityProviderProtocol {
    let accountIdentifiers: any AccountIdentifierProviderProtocol

    static func makeDefault() -> Self {
        let applicationIdentifier = Bundle.main.bundleIdentifier ?? "com.broadapps.platform.example"
        return Self(
            accountIdentifiers: KeychainAccountIdentifierStore(
                configuration: KeychainAccountIdentifierConfiguration(
                    service: "\(applicationIdentifier).account",
                    // Enable cross-device identity only with a confirmed account-recovery contract.
                    synchronizesThroughICloudKeychain: false
                ),
                failureError: .example(
                    message: "Не удалось восстановить аккаунт. Повторите попытку после разблокировки устройства.",
                    code: "example.account.keychain-unavailable"
                )
            )
        )
    }

    func identity(for subject: EntitlementSubject) async -> AdaptyCustomerIdentity? {
        guard case let .resolved(identifier, _) = await accountIdentifiers.resolve() else {
            return nil
        }
        return AdaptyCustomerIdentity(subject: subject, customerUserID: identifier)
    }
}

/// A nil Adapty identity permits anonymous activation. Stop before the SDK when
/// Keychain fails, so it cannot silently create a different anonymous customer.
struct ExampleIdentityActivationRepository: MonetizationRepositoryProtocol {
    let accountIdentifiers: any AccountIdentifierProviderProtocol
    let repository: any MonetizationRepositoryProtocol

    func activate() async -> MonetizationActivationOutcome {
        if case let .failed(error) = await accountIdentifiers.resolve() {
            return .unavailable(error)
        }
        return await repository.activate()
    }
}

struct ExampleAccountIdentityPaywallRepository: PaywallRepositoryProtocol {
    let accountIdentifiers: any AccountIdentifierProviderProtocol
    let repository: any PaywallRepositoryProtocol

    func loadPaywall(for placement: PlacementID) async -> PaywallLoadOutcome {
        if case let .failed(error) = await accountIdentifiers.resolve() {
            return .unavailable(error)
        }
        return await repository.loadPaywall(for: placement)
    }
}
