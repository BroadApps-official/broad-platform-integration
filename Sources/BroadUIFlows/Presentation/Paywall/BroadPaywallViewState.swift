import BroadCore
import BroadMonetization
import Foundation

public enum BroadPaywallViewState: Equatable, Sendable {
    case idle
    case loading
    case content(PaywallPayload)
    case empty(PaywallPayload)
    case failure(AppError)

    public var payload: PaywallPayload? {
        switch self {
        case let .content(payload), let .empty(payload):
            payload
        case .idle, .loading, .failure:
            nil
        }
    }
}

public enum BroadPaywallInlineFeedback: Equatable, Sendable {
    case notice(String)
    case failure(AppError)
}

public enum BroadPaywallCompletion: Equatable, Sendable {
    case purchased(EntitlementSnapshot)
    case restored(EntitlementSnapshot)
}

public struct BroadPaywallCompletionEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let completion: BroadPaywallCompletion

    init(completion: BroadPaywallCompletion) {
        id = UUID()
        self.completion = completion
    }
}
