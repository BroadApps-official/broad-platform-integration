import BroadCore
import Foundation

public actor KeyValueAppFlowProgressRepository: AppFlowProgressRepositoryProtocol {
    private static let marker = Data([1])

    private let keyValueStore: any KeyValueStoreProtocol
    private let onboardingCompletedKey: String
    private let initialPaywallResolvedKey: String

    public init(
        keyValueStore: any KeyValueStoreProtocol,
        keyPrefix: String = "app-flow"
    ) {
        precondition(
            !keyPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "AppFlow key prefix must not be empty"
        )

        self.keyValueStore = keyValueStore
        onboardingCompletedKey = "\(keyPrefix).onboarding-completed.v1"
        initialPaywallResolvedKey = "\(keyPrefix).initial-paywall-resolved.v1"
    }

    public func loadCheckpoint() async -> AppFlowCheckpoint {
        if await containsMarker(forKey: initialPaywallResolvedKey) {
            return .initialPaywallResolved
        }

        if await containsMarker(forKey: onboardingCompletedKey) {
            return .onboardingCompleted
        }

        return .start
    }

    @discardableResult
    public func advance(to checkpoint: AppFlowCheckpoint) async -> AppFlowCheckpoint {
        switch checkpoint {
        case .start:
            break
        case .onboardingCompleted:
            await writeMarker(forKey: onboardingCompletedKey)
        case .initialPaywallResolved:
            await writeMarker(forKey: onboardingCompletedKey)
            await writeMarker(forKey: initialPaywallResolvedKey)
        }

        return await loadCheckpoint()
    }

    private func containsMarker(forKey key: String) async -> Bool {
        do {
            guard case let .data(data) = try await keyValueStore.read(key) else {
                return false
            }

            return data == Self.marker
        } catch {
            return false
        }
    }

    private func writeMarker(forKey key: String) async {
        try? await keyValueStore.write(Self.marker, forKey: key)
    }
}
